{
  config,
  lib,
  flake,
  hostName,
  ...
}: let
  inherit (lib) mkIf mkDefault;
  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getAddress getServiceVariables;

  inherit
    (getServiceVariables "forgejo")
    serviceName
    portName
    networkCfg
    cfg
    ports
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      configEnable = {
        ports.${portName}.port = mkDefault 3000;
      };
    }))
  ];
  config = mkIf (networkCfg.enable && cfg.enable) {
    services.forgejo = {
      enable = true;
      inherit (cfg) stateDir;
      settings = {
        server = {
          ROOT_URL = getAddress {
            protocol = "https";
            inherit portName;
          };
          HTTP_PORT = ports.${portName}.port;
        };
      };
    };
  };
}
