{
  config,
  hostName,
  lib,
  ...
}: let
  inherit (lib) mkIf;

  cfg = config.network.services.forgejo;
in {
  options.network.services.forgejo = config.lib.network.mkServiceOptions;
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
