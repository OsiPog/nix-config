{
  config,
  hostName,
  lib,
  flake,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  inherit (flake.lib) mkServiceOptionsModule;

  cfg = config.network.services.nextcloud;
in {
  imports = [
    (mkServiceOptionsModule "nextcloud")
  ];

  config = mkMerge [
    {
      assertions = [
        {
          assertion = config.network.services.nextcloud.port == 80;
          message = "Nextcloud needs to run on port 80 because the port is not configurable through NixOS";
        }
      ];
    }
    (mkIf (cfg.enable && cfg.host == hostName) {
      sops.secrets."nextcloud/adminpass" = {};

      services.nextcloud = {
        enable = true;
        package = pkgs.nextcloud31;
        hostName = config.lib.network.toFullDomain "nextcloud";
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
