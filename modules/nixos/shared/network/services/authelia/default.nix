{
  config,
  lib,
  flake,
  ...
}: let
  inherit (lib) mkIf;
  inherit (flake.lib) mkServiceOptionsModule;
  inherit (config.lib.network) isServiceEnabledOnHost;

  serviceName = "authelia";
  cfg = config.network.services.${serviceName};
in {
  imports = [
    (mkServiceOptionsModule serviceName)
  ];
  config = mkIf (isServiceEnabledOnHost serviceName) {
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
        address = "http://0.0.0.0:${toString cfg.port}";

        log = {
          level = "info";
        };
      };
    };
  };
}
