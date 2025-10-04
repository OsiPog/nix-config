{
  config,
  hostName,
  lib,
  flake,
  ...
}: let
  inherit (lib) mkIf;
  inherit (flake.lib) mkServiceOptionsModule;

  cfg = config.network.services.authelia;
in {
  imports = [
    (mkServiceOptionsModule "authelia")
  ];
  config = mkIf (cfg.enable && cfg.host == hostName) {
    sops.secrets = {
      "authelia/jwtSecret" = {owner = config.services.authelia.instances.default.user;};
      "authelia/storageEncryptionKey" = {owner = config.services.authelia.instances.default.user;};
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
