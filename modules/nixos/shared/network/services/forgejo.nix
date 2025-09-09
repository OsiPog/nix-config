{
  config,
  hostName,
  lib,
  flake,
  ...
}: let
  inherit (lib) mkIf;
  inherit (flake.lib) mkServiceOptionsModule;

  cfg = config.network.services.forgejo;
in {
  imports = [
    (mkServiceOptionsModule "forgejo")
  ];
  config = mkIf (cfg.enable && cfg.host == hostName) {
    services.forgejo = {
      enable = true;
      settings = {
        server = {
          ROOT_URL = "https://" + (config.lib.network.toFullDomain "forgejo");
          HTTP_PORT = cfg.port;
        };
      };
    };
  };
}
