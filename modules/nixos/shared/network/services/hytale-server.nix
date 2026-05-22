{
  config,
  lib,
  flake,
  pkgs,
  ...
}: let
  inherit (lib) mkOption mkIf mkDefault;
  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getServiceVariables;

  inherit
    (getServiceVariables "hytale-server")
    serviceName
    networkCfg
    cfg
    ports
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      optionsService = {
      };
      configEnable.ports.hytale = {
        port = mkDefault 5520;
        udp = true;
        reverseProxy.method = "stream";
      };
    }))

    flake.inputs.nix-hytale-server.nixosModules.hytale-server
  ];

  config = mkIf (networkCfg.enable && cfg.enable) {
    services.hytale-server = {
      enable = true;
      stateDir = cfg.stateDir;
      port = ports.hytale.port;
      useRecommendedJvmOpts = true;
    };
  };
}
