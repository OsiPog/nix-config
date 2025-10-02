{
  config,
  hostName,
  lib,
  flake,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  inherit (flake.lib) mkServiceOptionsModule;

  cfg = config.network.services.nextcloud;
in {
  imports = [
    (mkServiceOptionsModule "nextcloud")
  ];
  config = mkIf (cfg.enable && cfg.host == hostName) {
    sops.secrets."nextcloud/adminpass" = {};

    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud31;
      hostName = config.lib.network.toFullDomain "nextcloud";
      config = {
        adminuser = "admin";
        adminpassFile = config.getSopsFile "nextcloud/adminpass";
        dbtype = "sqlite";
      };
      settings = {
        overwriteprotocol = "https";
      };
      extraApps = {
        inherit
          (pkgs.nextcloud31Packages.apps)
          calendar
          ;
      };
      extraAppsEnable = true;
    };

    networking.firewall.allowedTCPPorts = [cfg.port];
  };
}
