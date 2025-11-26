{
  config,
  lib,
  flake,
  pkgs,
  hostName,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  inherit (flake.lib) mkServiceOptionsModule;
  inherit (config.lib.network) toFullDomain;

  serviceName = "nextcloud";
  networkCfg = config.network;
  cfg = networkCfg.hosts.${hostName}.services.${serviceName};
in {
  imports = [
    (mkServiceOptionsModule serviceName {})
  ];

  config = mkMerge [
    (mkIf (networkCfg.enable && cfg.enable) {
      assertions = [
        {
          assertion = cfg.ports.web.port == 80;
          message = "The nextcloud port needs to be 80 as that cannot be configured.";
        }
      ];
      sops.secrets."nextcloud/adminpass" = {sopsFile = ./secrets.yaml;};

      services.nextcloud = {
        enable = true;
        package = pkgs.nextcloud31;
        home = cfg.stateDir;
        hostName = toFullDomain {
          inherit serviceName;
          portName = "web";
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
