{
  lib,
  config,
  flake,
  hostName,
  pkgs,
  ...
}: let
  inherit (builtins) mapAttrs attrValues;
  inherit (lib) pipe types mkIf mkOption mkMerge groupBy concatMapStringsSep;
  inherit (lib.attrsets) filterAttrs mapAttrs';

  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getServiceVariables;

  inherit
    (getServiceVariables "backup")
    serviceName
    networkCfg
    cfg
    ;

  # common restic backup options, only depends on the repo path
  commonBackupOptions = {
    repository = cfg.repoPath;
    # we assume that the password sits in the repo
    passwordFile = "${cfg.repoPath}/password";
    inhibitsSleep = true;
    timerConfig = {
      OnCalendar = "15:05";
      Persistent = true;
      RandomizedDelaySec = "5h";
    };
  };
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      optionsService = {
        repoPath = mkOption {
          type = types.pathWith {absolute = true;};
          description = "Path where the restic backup repository is located. The repo password is expected at <repoPath>/password.";
        };
        mirrorPath = mkOption {
          type = types.pathWith {absolute = true;};
          description = "Path where remote hosts' backup paths are mirrored (via rsync) before being backed up.";
        };
      };
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    # a stub `command` backup to allow repo access (also enables restic itself)
    {
      # only exists to have a common command to access the repo
      services.restic.backups.command =
        commonBackupOptions
        // {
          createWrapper = true;
        };
    }

    # configure the actual backups once services provide paths to back up
    (mkIf (cfg.require.backup-paths != {}) (let
      # one backup per host
      pathsByHost = groupBy (p: p.host) (attrValues cfg.require.backup-paths);
    in {
      services.restic.backups = mapAttrs (backupHost: paths: let
        isRemote = backupHost != hostName;
        mirrorOf = p: "${cfg.mirrorPath}/${backupHost}${p.path}";
      in
        commonBackupOptions
        // {
          paths =
            map (p:
              if isRemote
              then mirrorOf p # remote: back up the mirrored copy
              else p.path) # local: no post processing
            
            paths;
          # tag snapshots with the origin host, not the backup server
          extraBackupArgs = ["--host ${backupHost}"];
          # remote hosts: mirror before backup, fail (and retry next interval) if unreachable
          backupPrepareCommand = mkIf isRemote ''
            ${pkgs.openssh}/bin/ssh -o ConnectTimeout=3 -i /etc/ssh/id_ed25519 root@${backupHost} echo "Connection succeeded!"
            ${concatMapStringsSep "\n" (p: ''
                mkdir -p "${mirrorOf p}"
                ${pkgs.rsync}/bin/rsync -a --delete --info=progress2 -e "ssh -i /etc/ssh/id_ed25519" "root@${backupHost}:${p.path}/" "${mirrorOf p}/"
              '')
              paths}
          '';
        })
      pathsByHost;

      # remote-host backups should retry when the host is offline
      systemd.services = pipe pathsByHost [
        (filterAttrs (backupHost: _: backupHost != hostName))
        (
          mapAttrs' (backupHost: _: {
            name = "restic-backups-${backupHost}";
            value = {
              serviceConfig = {
                Restart = "on-failure";
                RestartSec = "15min";
              };
            };
          })
        )
      ];
    }))
  ]);
}
