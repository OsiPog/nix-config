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

  config = mkIf (cfg.enable && cfg.host == hostName) {
    sops.secrets."nextcloud/adminpass" = {};

    services.nginx.virtualHosts.${config.services.nextcloud.hostName}.listen = [
      {
        inherit (cfg) port;
        addr = "127.0.0.1";
      }
    ];

    networking.firewall.allowedTCPPorts = [cfg.port];

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
  };
}
