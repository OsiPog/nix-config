{
  config,
  lib,
  flake,
  hostName,
  ...
}: let
  inherit (builtins) concatStringsSep;
  inherit (lib) mkIf pipe mkMerge mkDefault;
  inherit (lib.strings) splitString;

  inherit (flake.lib) mkServiceOptionsModule;
  inherit (config.lib.network) toFullDomain;

  serviceName = "portunus";
  networkCfg = config.network;
  cfg = networkCfg.hosts.${hostName}.services.${serviceName};

  baseDomain = networkCfg.hosts.${cfg.ports.web.reverseProxy.host}.reverseProxy.domain;
in {
  imports = [
    (mkServiceOptionsModule serviceName {
      portsDefault = {
        ldap.port = 636;
      };
    })
    flake.nixosModules.porkbunAcme
  ];
  config = mkMerge [
    (mkIf (networkCfg.enable && cfg.enable) {
      sops.secrets."portunus/admin-pass" = {
        sopsFile = ./secrets.yaml;
        owner = config.services.portunus.user;
      };

      # custom module that sets up acme with porkbun
      services.porkbunAcme = {
        enable = true;
        certName = config.services.portunus.domain;
        domain = config.services.portunus.domain;
      };

      services.portunus = {
        enable = true;
        domain = toFullDomain {
          inherit serviceName;
          portName = "web";
        };
        ldap = {
          # build a valid RDN with only dc components of the reverse proxy domain (https://github.com/majewsky/portunus?tab=readme-ov-file#ldap-directory-structure)
          suffix = pipe baseDomain [
            (splitString ".")
            (map (e: "dc=${e}"))
            (concatStringsSep ",")
          ];
        };
        port = cfg.ports.web.port;
        seedSettings = {
          groups = [
            {
              name = "admin-team";
              long_name = "Portunus Administrators";
              members = ["technical-admin"];
              permissions = {
                portunus = {is_admin = true;};
                ldap = {can_read = true;};
              };
              posix_gid = 101;
            }
          ];
          users = [
            {
              login_name = "technical-admin";
              given_name = "Technical";
              family_name = "Administrator";
              email = "noreply@${baseDomain}";
              password = {
                from_command = ["cat" (config.getSopsFile "portunus/admin-pass")];
              };
            }
          ];
        };
      };

      systemd.services.portunus.environment = {
        PORTUNUS_SERVER_HTTP_LISTEN = lib.mkForce "0.0.0.0:${toString config.services.portunus.port}";
      };
    })
  ];
}
