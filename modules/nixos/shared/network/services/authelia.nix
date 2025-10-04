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
    services.authelia.instances.default = {
      enable = true;
      settings = {
        server = {
          host = "0.0.0.0";
          port = cfg.port;
        };
        log = {
          level = "info";
        };
      };
    };
  };
}