{
  config,
  lib,
  flake,
  hostName,
  ...
}: let
  inherit (lib) mkIf mkDefault;
  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getAddress getVariables;

  inherit
    (getVariables "forgejo")
    serviceName
    portName
    networkCfg
    cfg
    ports
    stateDir
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      configEnable = {
        stateDirs = [stateDir];
        ports.${portName}.port = mkDefault 3000;
      };
    }))
  ];
  config = mkIf (networkCfg.enable && cfg.enable) {
    services.forgejo = {
      enable = true;
      inherit stateDir;
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
