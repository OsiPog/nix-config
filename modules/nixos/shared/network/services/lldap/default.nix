{
  config,
  lib,
  flake,
  hostName,
  pkgs,
  ...
}: let
  inherit (builtins) concatStringsSep;
  inherit (lib) mkIf pipe mkOption mkDefault;
  inherit (lib.strings) splitString;

  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getAddress getVariables;

  inherit
    (getVariables "lldap")
    serviceName
    networkCfg
    cfg
    ports
    stateDir
    ;

  ldapsDomain = getAddress {
    portName = "ldaps";
    appendPort = false;
  };
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      optionsService = {
        ldap = {
          baseDN = mkOption {
            # build a valid RDN with only dc components of the reverse proxy domain
            default = pipe ldapsDomain [
              (splitString ".")
              (map (e: "dc=${e}"))
              (concatStringsSep ",")
            ];
            description = "The base DN of the LDAP server";
            readOnly = true;
          };
          userDN = mkOption {
            default = "admin";
            description = "The DN of the admin user";
          };
          userEmail = mkOption {
            default = "admin@${ldapsDomain}";
            description = "The email of the admin user";
          };
        };
      };
      configEnable = {
        stateDirs = [stateDir];
        ports = {
          lldap.port = 17170;
          ldaps = {
            port = 6360;
            reverseProxy.method = "stream";
          };
        };
      };
    }))

    flake.nixosModules.porkbunAcme
    flake.nixosModules.lldapBootstrap
  ];

  config = mkIf (networkCfg.enable && cfg.enable) {
    assertions = [
      {
        assertion = ports.ldaps.reverseProxy.enable;
        message = "ldaps port needs to be reverse proxied to ensure the server can be reached on a domain.";
      }
      {
        assertion = ports.lldap.reverseProxy.enable;
        message = "lldap port needs to be reverse proxied to ensure the server can be reached on a domain.";
      }
    ];

    sops.secrets = {
      "lldap/admin-pass" = {
        owner = "lldap";
        sopsFile = ./secrets.yaml;
      };
    };

    # TLS
    services.porkbunAcme = {
      enable = true;
      domain = ldapsDomain;
    };

    users.groups.lldap = {};
    users.users.lldap = {
      group = "lldap";
      isSystemUser = true;

      # Give lldap user access to ACME certificates
      extraGroups = ["acme"];
    };

    # LLDAP service configuration
    services.lldap = {
      enable = true;
      settings = {
        verbose = true;
        http_host = "0.0.0.0";
        http_port = ports.lldap.port;
        ldap_base_dn = cfg.ldap.baseDN;
        ldap_user_dn = cfg.ldap.userDN;
        ldap_user_pass_file = config.getSopsFile "lldap/admin-pass";
        database_url = "sqlite://${stateDir}/users.db?mode=rwc";
        force_ldap_user_pass_reset = "always";
        ldaps_options = let
          acmeDirectory = config.security.acme.certs.${ldapsDomain}.directory;
        in {
          enabled = true;
          port = ports.ldaps.port;
          cert_file = "${acmeDirectory}/cert.pem";
          key_file = "${acmeDirectory}/key.pem";
        };
      };
      bootstrap = {
        enable = true;
        cleanup = {
          enable = true;
          keepUsers = true;
          keepGroupMembership = true;
        };
      };
    };

    # Ensure state directory is owned by lldap
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0750 lldap lldap -"
    ];
  };
}
