{
  config,
  lib,
  flake,
  pkgs,
  hostName,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getAddress getVariables;

  inherit
    (getVariables "nextcloud")
    serviceName
    portName
    networkCfg
    cfg
    ports
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      configEnable.ports.${portName}.port = 80;
    }))
  ];

  config = mkMerge [
    (mkIf (networkCfg.enable && cfg.enable) {
      sops.secrets."nextcloud/adminpass" = {sopsFile = ./secrets.yaml;};

      services.nextcloud = {
        enable = true;
        package = pkgs.nextcloud31;
        home = cfg.stateDir;
        hostName = getAddress {
          inherit portName;
        };
        https = true;
        config = {
          adminuser = "admin";
          adminpassFile = config.getSopsFile "nextcloud/adminpass";
          dbtype = "sqlite";
        };
        extraApps = {
          inherit
            (pkgs.nextcloud31Packages.apps)
            calendar
            ;
        };
        extraAppsEnable = true;
      };
    })
  ];
}
