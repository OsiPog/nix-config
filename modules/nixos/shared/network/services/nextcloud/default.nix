{
  config,
  lib,
  flake,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  inherit (flake.lib) mkServiceOptionsModule;
  inherit (config.lib.network) isServiceEnabledOnHost toFullDomain;

  serviceName = "nextcloud";
  cfg = config.network.services.${serviceName};
in {
  imports = [
    (mkServiceOptionsModule serviceName)
  ];

  config = mkMerge [
    {
      assertions = [
        {
          assertion = cfg.ports.web.port == 80;
          message = "The nextcloud port needs to be 80 as that cannot be configured.";
        }
      ];
    }
    (mkIf (isServiceEnabledOnHost serviceName) {
      sops.secrets."nextcloud/adminpass" = {sopsFile = ./secrets.yaml;};

      services.nextcloud = {
        enable = true;
        package = pkgs.nextcloud31;
        hostName = toFullDomain serviceName "web";
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
