{
  config,
  lib,
  flake,
  ...
}: let
  inherit (lib) mkIf mkDefault;
  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getServiceVariables;

  inherit
    (getServiceVariables "jellyfin")
    serviceName
    portName
    networkCfg
    cfg
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      configEnable = {
        ports.${portName}.port = mkDefault 8096;
      };
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) {
    services.jellyfin = {
      enable = true;
      hardwareAcceleration.enable = true;
      dataDir = cfg.stateDir;
    };
  };
}
