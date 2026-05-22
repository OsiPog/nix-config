{
  config,
  hostName,
  lib,
  flake,
  ...
}: let
  inherit (lib) mkDefault mkIf mkForce;
  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getServiceVariables;

  inherit
    (getServiceVariables "tailscale")
    serviceName
    networkCfg
    cfg
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({name, ...}: {
      provideEnable = {
        tailscale-client = {
          ip = mkDefault (throw "Tailscale IP address of ${name} is not defined.");
          magicDns = mkDefault name;
        };
      };
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (let
    tailscaleServer = cfg.require.tailscale-server;
  in {
    sops.secrets = tailscaleServer.secrets;

    services.kresd.enable = mkForce false;

    services.tailscale = {
      enable = true;
      openFirewall = true;
      interfaceName = "sculk";
      useRoutingFeatures = "both";
      authKeyFile = config.getSopsFile tailscaleServer.authKeySecretName;
      extraUpFlags = [
        "--login-server=${tailscaleServer.address "proxyProtocol://domain"}"
        "--hostname=${hostName}"
      ];
    };
  });
}
