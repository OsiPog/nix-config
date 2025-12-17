{
  lib,
  config,
  flake,
  hostName,
  pkgs,
  ...
}: let
  inherit (builtins) filter attrValues length mapAttrs foldl';
  inherit (lib) types mkIf mkOption mkEnableOption mkMerge pipe;
  inherit (lib.attrsets) filterAttrs attrsToList recursiveUpdate;

  inherit (flake.lib) mkServiceOptionsModule nixosHostNames;

  serviceName = "backup";
  networkCfg = config.network;
  cfg = networkCfg.hosts.${hostName}.services.${serviceName};
in {
  imports = [
    (mkServiceOptionsModule serviceName {
      settingsOptions = {
        paths = mkOption {
          type = with types; listOf (pathWith {absolute = true;});
          description = "The paths that should be backed up";
          default = [];
        };
        serviceBackup = mkOption {
          description = "Whether to backup the stateDir of every enabled service on this host.";
          default = true;
          type = types.bool;
        };
        exclude = mkOption {
          type = with types; listOf str;
          description = "Patterns of files to exclude";
          default = [];
        };
        host = mkOption {
          type = types.str;
          default = hostName;
          description = "The host where a backup server is running.";
        };
        server = {
          enable = mkEnableOption "the backup server";
          repository = mkOption {
            type = types.pathWith {absolute = true;};
          };
        };
      };
    })
  ];
  config = mkMerge [
    # config for clients
    (mkIf (networkCfg.enable && cfg.enable) {
      # Allow all backup servers access to current host
      users.users.root.openssh.authorizedKeys.keys = pipe networkCfg.hosts [
        attrValues
        (filter (host: host.services.backup.enable && host.services.backup.settings.host == hostName))
        (map (host: host.ssh.publicKey))
      ];
    })
    # config for backup server
    (mkIf (networkCfg.enable && cfg.settings.server.enable) (let
      backupMount = "/mnt/backup";

      commonBackupOptions = {
        inherit (cfg.settings.server) repository;
        # we assume that the password sits in the repo
        passwordFile = "${cfg.settings.server.repository}/password";
        inhibitsSleep = true;
        timerConfig = {
          OnCalendar = "15:05";
          Persistent = true;
          RandomizedDelaySec = "5h";
        };
      };

      backupPathsOf = hostName: let
        host = networkCfg.hosts.${hostName};
      in (host.services.backup.settings.paths
        ++ (
          if host.services.backup.settings.serviceBackup
          then
            pipe host.services [
              (filterAttrs (serviceName: _: serviceName != "backup"))
              attrValues
              (filter (e: e.enable))
              (map (e: e.stateDir))
            ]
          else []
        ));
      relevantHosts = (filterAttrs (_: host: host.services.backup.enable && host.services.backup.settings.host == hostName)) networkCfg.hosts;
    in {
      services.restic.backups =
        (mapAttrs (hostName: host:
          commonBackupOptions
          // {
            paths =
              map (
                path:
                  if hostName != host.services.backup.settings.host
                  then "${backupMount}/${hostName}${path}"
                  else path
              )
              (backupPathsOf hostName);
            extraBackupArgs = ["--host ${hostName}"];
          })
        relevantHosts)
        // {
          # prune job
          prune =
            commonBackupOptions
            // {
              pruneOpts = let
                perHost = 2;
                countStr = toString ((length nixosHostNames) * perHost);
              in [
                "--keep-daily ${countStr}"
                "--keep-weekly ${countStr}"
                "--keep-monthly ${countStr}"
                "--keep-yearly ${countStr}"
              ];
            };
          # only exists to have a common command to access the repo
          command =
            commonBackupOptions
            // {
              createWrapper = true;
            };
        };

      # Make services automatically restart when failed (hosts might be offline)
      systemd.services = pipe relevantHosts [
        attrsToList
        # only remote hosts
        (filter (host: host.name != hostName))
        (map (host: {
          # Service that mounts the remote host via SSHFS
          "sshfs-${host.name}" = {
            path = with pkgs; [
              sshfs
              openssh
            ];
            script = ''
              # 1. check connection is possible at all
              ssh -o ConnectTimeout=3 -i /etc/ssh/id_ed25519 "root@${host.name}" echo "Connection succeeded!"
              # 2. mount
              sshfs root@${host.name}:/ ${backupMount}/${host.name} \
                -o IdentityFile=/etc/ssh/id_ed25519 \
                -o auto_unmount \
                -o allow_root \
                -f
            '';
          };
          # Additional options to restic backup service
          "restic-backups-${host.name}" = {
            path = with pkgs; [
              systemd
            ];
            preStart = ''
              systemctl start sshfs-${host.name}
              sleep 5
            '';
            postStop = ''
              # After backup unmount sshfs
              systemctl stop sshfs-${host.name}
            '';
            serviceConfig = {
              Restart = "on-failure";
              RestartSec = "15min";
            };
          };
        }))
        # concat all these attrsets
        (foldl' recursiveUpdate {})
      ];
    }))
  ];
}
