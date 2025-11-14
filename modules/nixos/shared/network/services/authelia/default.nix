{
  config,
  lib,
  flake,
  hostName,
  ...
}: let
  inherit (lib) mkIf;
  inherit (flake.lib) mkServiceOptionsModule;

  serviceName = "authelia";
  networkCfg = config.network;
  cfg = networkCfg.hosts.${hostName}.services.${serviceName};
in {
  imports = [
    (mkServiceOptionsModule serviceName {})
  ];
  config = mkIf (networkCfg.enable && cfg.enable) {
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

    services.authelia.instances.default = {
      enable = true;
      secrets = {
        jwtSecretFile = config.getSopsFile "authelia/jwtSecret";
        storageEncryptionKeyFile = config.getSopsFile "authelia/storageEncryptionKey";
      };
      settings = {
        address = "http://0.0.0.0:${toString cfg.ports.web.port}";

        log = {
          level = "info";
        };
      };
    };
  };
}
