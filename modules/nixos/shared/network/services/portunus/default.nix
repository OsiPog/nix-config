{
  config,
  lib,
  flake,
  hostName,
  pkgs,
  ...
}: let
  inherit (builtins) concatStringsSep;
  inherit (lib) mkIf pipe mkOption;
  inherit (lib.strings) splitString;

  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getAddress getVariables;

  inherit
    (getVariables "portunus")
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
            description = "The base dn of the ldap server";
            readOnly = true;
          };
        };
      };
      configEnable = {
        stateDirs = [stateDir];
        ports = {
          portunus.port = 6000;
          ldaps = {
            port = 636;
            reverseProxy.method = "stream";
          };
        };
      };
    }))

    flake.nixosModules.porkbunAcme
  ];

  config = mkIf (networkCfg.enable && cfg.enable) {
    assertions = [
      {
        assertion = ports.ldaps.reverseProxy.enable;
        message = "ldaps port needs to be reverse proxied to ensure the server can be reached on a domain.";
      }
    ];

    sops.secrets."portunus/admin-pass" = {
      sopsFile = ./secrets.yaml;
      owner = config.services.portunus.user;
    };

    # TLS
    services.porkbunAcme = {
      enable = true;
      domain = ldapsDomain;
    };

    users.users.portunus.extraGroups = ["acme"];

    # Portunus service configuration
    services.portunus = {
      enable = true;
      stateDir = stateDir;
      domain = getAddress {
        portName = "portunus";
      };
      ldap = {
        tls = false; # we do it manually because limitations in nixpkgs module, see below in `environment`
        suffix = cfg.ldap.baseDN;
      };
      port = ports.portunus.port;
      seedSettings = {
        groups = [
          {
            name = "admin-team";
            long_name = "Portunus Administrators";
            members = ["technical-admin"];
            permissions = {
              portunus.is_admin = true;
              ldap.can_read = true;
            };
          }
        ];
        users = [
          {
            login_name = "technical-admin";
            given_name = "Technical";
            family_name = "Administrator";
            password = {
              from_command = ["cat" (config.getSopsFile "portunus/admin-pass")];
            };
          }
        ];
      };
    };

    systemd.services.portunus.environment =
      {
        # PORTUNUS_DEBUG = "true";
        PORTUNUS_SERVER_HTTP_LISTEN = lib.mkForce "0.0.0.0:${toString config.services.portunus.port}";
      }
      // (let
        acmeDirectory = config.security.acme.certs."${ldapsDomain}".directory;
      in {
        PORTUNUS_SLAPD_TLS_CA_CERTIFICATE = config.security.pki.caBundle;
        PORTUNUS_SLAPD_TLS_CERTIFICATE = "${acmeDirectory}/cert.pem";
        PORTUNUS_SLAPD_TLS_DOMAIN_NAME = ldapsDomain;
        PORTUNUS_SLAPD_TLS_PRIVATE_KEY = "${acmeDirectory}/key.pem";
      });
  };
}
