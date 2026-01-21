{
  config,
  lib,
  flake,
  hostName,
  ...
}: let
  inherit (lib) mkIf mkDefault;
  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getServiceVariables getAddress;

  inherit
    (getServiceVariables "opencloud")
    serviceName
    networkCfg
    cfg
    ports
    portName
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      configEnable.ports.${portName}.port = mkDefault 9200;
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) {
    services.opencloud = {
      enable = true;
      stateDir = cfg.stateDir;
      address = "0.0.0.0";
      port = ports.opencloud.port;
      url = getAddress {
        protocol = "https";
        inherit portName;
        inherit hostName;
      };
      environment = {
        PROXY_TLS = "false"; # TLS handled by reverse proxy
      };
      # settings = {
      #   proxy.proxy.http.tls = false;
      # };
    };
  };
}
