{
  config,
  lib,
  flake,
  hostName,
  ...
}: let
  inherit (lib) mkIf mkOption;

  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getAddress getServiceVariables;

  inherit
    (getServiceVariables "authelia")
    serviceName
    portName
    networkCfg
    cfg
    ports
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      optionsService.mailHost = mkOption {
        description = "The host on which the mailserver is running";
        type = with lib.types; nullOr str;
        default = null;
      };
      configEnable = {
        ports.${portName}.port = 9091;
      };
      configService.stateDir = "/var/lib/authelia-default"; # hardcoded in nixpkgs
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
      settings = {
        server.address = "tcp://:${toString ports.${portName}.port}";
        log.level = "info";
        storage.local.path = "${cfg.stateDir}/db.sqlite3";
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
      };
    };
  };
}
