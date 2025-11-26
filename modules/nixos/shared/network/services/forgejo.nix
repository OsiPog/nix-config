{
  config,
  lib,
  flake,
  hostName,
  ...
}: let
  inherit (lib) mkIf;
  inherit (flake.lib) mkServiceOptionsModule;
  inherit (config.lib.network) toFullDomain;

  serviceName = "forgejo";
  networkCfg = config.network;
  cfg = networkCfg.hosts.${hostName}.services.${serviceName};
in {
  imports = [
    (mkServiceOptionsModule serviceName {})
  ];
  config = mkIf (networkCfg.enable && cfg.enable) {
    services.forgejo = {
      enable = true;
      inherit (cfg) stateDir;
      settings = {
        server = {
          ROOT_URL =
            "https://"
            + (toFullDomain {
              inherit serviceName;
              portName = "web";
            });
          HTTP_PORT = cfg.ports.web.port;
        };
      };
    };
  };
}
