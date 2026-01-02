{
  config,
  lib,
  flake,
  hostName,
  ...
}: let
  inherit (lib) mkIf mkOption;

  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getAddress getVariables;

  inherit
    (getVariables "authelia")
    serviceName
    portName
    networkCfg
    cfg
    ports
    stateDir
    ;

  domain = getAddress {inherit portName;};
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      optionsService.mailHost = mkOption {
        description = "The host on which the mailserver is running";
        type = with lib.types; nullOr str;
        default = null;
      };
      configEnable = {
        stateDirs = [stateDir];
        ports.${portName}.port = 9091;
      };
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) {
    assertions = [
      {
        assertion = ports.authelia.reverseProxy.enable;
        message = "Authelia needs to be reverse proxied as https is required.";
      }
    ];

    # Authelia secrets
    sops.secrets = {
      "authelia/jwtSecret" = {
        owner = config.services.authelia.instances.default.user;
        sopsFile = ./secrets.yaml;
      };
      "authelia/storageEncryptionKey" = {
        owner = config.services.authelia.instances.default.user;
        sopsFile = ./secrets.yaml;
      };
    };

    # Authelia service configuration
    services.authelia.instances.default = {
      enable = true;
      secrets = {
        jwtSecretFile = config.getSopsFile "authelia/jwtSecret";
        storageEncryptionKeyFile = config.getSopsFile "authelia/storageEncryptionKey";
      };
      environmentVariables = {
        # AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = config.getSopsFile "portunus/admin-pass";
      };
      settings = {
        server.address = "tcp://:${toString ports.${portName}.port}";
        log.level = "info";
        storage.local.path = "${stateDir}/db.sqlite3";
        session.cookies = [
          {
            domain = getAddress {
              portName = "authelia";
            };
            authelia_url = getAddress {
              protocol = "https";
              portName = "authelia";
            };
          }
        ];
        access_control.default_policy = "one_factor";
        notifier.smtp = {
          # we assume that the mailserver is accessable on the domain
          address = getAddress {
            protocol = "smtp";
            portName = "smtp";
            hostName = cfg.mailHost;
          };
          sender = "noreply@${domain}";
          username = "technical-admin";
        };
      };
    };
  };
}
