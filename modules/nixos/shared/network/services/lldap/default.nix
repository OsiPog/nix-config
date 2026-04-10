{
  config,
  lib,
  flake,
  ...
}: let
  inherit (builtins) concatStringsSep;
  inherit (lib) mkIf pipe mkForce;
  inherit (lib.strings) splitString;

  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getAddress getServiceVariables;

  inherit
    (getServiceVariables "lldap")
    serviceName
    networkCfg
    cfg
    ports
    integrations
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      configEnable = {
        ports = {
          lldap.port = 17170;
          ldaps = {
            port = 6360;
            reverseProxy.method = "stream";
          };
        };
      };
      integrationsEnable = {
        ldap.server = rec {
          address = getAddress {
            portName = "ldaps";
            hostName = "dead-voxel";
          };
          baseDN = pipe (address "domain") [
            (splitString ".")
            (map (e: "dc=${e}"))
            (concatStringsSep ",")
          ];
          userDN = "admin";
          userEmail = "admin@${address "domain"}";
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
      domain = integrations.ldap.server.address "domain";
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
        database_url = "sqlite://${cfg.stateDir}/users.db?mode=rwc";
        force_ldap_user_pass_reset = "always";
        ldaps_options = let
          acmeDirectory = config.security.acme.certs.${integrations.ldap.server.address "domain"}.directory;
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

    systemd = {
      services.lldap.serviceConfig.DynamicUser = mkForce false;
      # Ensure state directory is owned by lldap
      tmpfiles.rules = [
        "d ${cfg.stateDir} 0750 lldap lldap -"
      ];
    };
  };
}
