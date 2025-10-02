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
          assertion = cfg.port == 80;
          message = "The nextcloud port needs to be 80 as that cannot be configured.";
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
