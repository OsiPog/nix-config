{
  config,
  lib,
  flake,
  ...
}: let
  inherit (lib) mkIf;
  inherit (flake.lib) mkServiceOptionsModule;
  inherit (config.lib.network) isServiceEnabledOnHost toFullDomain;

  serviceName = "forgejo";
  cfg = config.network.services.${serviceName};
in {
  imports = [
    (mkServiceOptionsModule serviceName)
  ];
  config = mkIf (isServiceEnabledOnHost serviceName) {
    services.forgejo = {
      enable = true;
      settings = {
        server = {
          ROOT_URL = "https://" + (toFullDomain serviceName "web");
          HTTP_PORT = cfg.ports.web.port;
        };
      };
    };
  };
}
