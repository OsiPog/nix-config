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
    (getServiceVariables "home-assistant")
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
        ports.${portName} = {
          protocol = "http";
          port = mkDefault 8123;
        };
      };
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) {
    services.home-assistant = {
      enable = true;
      config.http = {
        server_port = ports.${portName}.port;
        use_x_forwarded_for = true;
        trusted_proxies = [
          (ports.${portName}.address "ip")
          "100.64.0.1" # TODO: remove when fixed
          "127.0.0.1"
          "::1"
        ];
      };
    };
  };
}
