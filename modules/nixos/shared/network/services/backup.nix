{
  lib,
  config,
  flake,
  hostName,
  pkgs,
  ...
}: let
  inherit (builtins) filter attrValues length mapAttrs listToAttrs;
  inherit (lib) types mkIf mkOption mkEnableOption mkMerge pipe;
  inherit (lib.attrsets) filterAttrs mapAttrs';
  inherit (lib.lists) flatten;

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
      # mount all needed directories using sshfs
      fileSystems =
        mapAttrs' (hostName: _: {
          name = "${backupMount}/${hostName}";
          value = {
            device = "root@${hostName}:/";
            fsType = "sshfs";
            options = [
              "nodev"
              "noatime"
              "noauto"
              "x-systemd.automount"
              "_netdev"

              "ServerAliveInterval=15"
              "IdentityFile=/etc/ssh/id_ed25519"
            ];
          };
        })
        relevantHosts;

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
      systemd.services = mkIf (hostName != cfg.settings.host) (
        mapAttrs' (hostName: host: {
          name = "restic-backups-${hostName}";
          value = {
            path = with pkgs; [
              openssh
              sshfs
              umount
            ];
            preStart = ''
              # check connection is possible at all
              ssh -o ConnectTimeout=3 -i /etc/ssh/id_ed25519 "root@${hostName}" echo "Connection succeeded!"
            '';
            postStop = ''
              # After backup unmount sshfs
              umount ${backupMount}/${hostName} --force
            '';
            serviceConfig = {
              Restart = "on-failure";
              RestartSec = "15min";
            };
          };
        })
        relevantHosts
      );
    }))
  ];
}
