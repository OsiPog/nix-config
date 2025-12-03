{
  lib,
  config,
  flake,
  hostName,
  ...
}: let
  inherit (builtins) filter attrValues;
  inherit (lib) types mkIf mkOption mkEnableOption mkMerge pipe;
  inherit (lib.attrsets) attrsToList;

  inherit (flake.lib) mkServiceOptionsModule;

  serviceName = "backup";
  networkCfg = config.network;
  cfg = networkCfg.hosts.${hostName}.services.${serviceName};

  backupUser = networkCfg.hosts.${cfg.settings.host}.services.backup.settings.server.user;
  backupMount = "/mnt/backup";
  backupRepository =
    if cfg.settings.host != hostName
    then backupMount
    else cfg.settings.server.repository;
  backupJobOptions = {
    # we assume that the password sits in the repo
    passwordFile = "${backupRepository}/password";
    repository = backupRepository;
    inhibitsSleep = true;
    timerConfig = {
      OnCalendar = "00:05";
      Persistent = true;
      RandomizedDelaySec = "5h";
    };
  };
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
          user = mkOption {
            description = "A user that has rw access to the repository.";
            default = "backup";
            type = types.str;
          };
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
      # Create an sshfs to the backup repo
      fileSystems.${backupMount} = mkIf (cfg.settings.host != hostName) {
        device = "${backupUser}@${cfg.settings.host}:${networkCfg.hosts.${cfg.settings.host}.services.backup.settings.server.repository}";
        fsType = "sshfs";
        options = [
          "nodev"
          "noatime"
          "allow_other"
          "IdentityFile=/etc/ssh/id_ed25519"
        ];
      };

      services.restic.backups.default =
        backupJobOptions
        // {
          inherit (cfg.settings) exclude;
          paths =
            cfg.settings.paths
            ++ (
              if cfg.settings.serviceBackup
              then
                pipe networkCfg.hosts.${hostName}.services [
                  attrValues
                  (filter (e: e.enable))
                  (map (e: e.stateDir))
                ]
              else []
            );
        };
    })
    # config for backup server
    (mkIf (networkCfg.enable && cfg.settings.server.enable) {
      users = {
        users.${backupUser} = {
          description = "User that can access the backup repository";
          home = cfg.settings.server.repository;
          isNormalUser = true;

          group = backupUser;
          openssh.authorizedKeys.keys = pipe networkCfg.hosts [
            attrValues
            (filter (host: host.services.backup.enable && host.services.backup.settings.host == hostName))
            (map (host: host.ssh.publicKey))
          ];
        };
        groups.${backupUser} = {};
      };

      # prune job
      services.restic.backups.prune =
        backupJobOptions
        // {
          createWrapper = true;
          pruneOpts = [
            "--keep-daily 7"
            "--keep-weekly 5"
            "--keep-monthly 12"
            "--keep-yearly 75"
          ];
        };
    })
  ];
}
