{
  config,
  lib,
  flake,
  hostName,
  ...
}: let
  inherit (builtins) concatStringsSep;
  inherit (lib) mkIf pipe mkOption;
  inherit (lib.strings) splitString;

  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getAddress getVariables;

  inherit
    (getVariables "auth-server")
    serviceName
    networkCfg
    cfg
    ports
    ;

  portunusStateDir = "/var/lib/portunus";
  autheliaStateDir = "/var/lib/authelia-default";
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      optionsService.domain = mkOption {
        type = lib.types.str;
        description = "The ldap suffix of the LDAP server";
        default = "example.com";
      };

      configEnable = {
        stateDirs = [portunusStateDir autheliaStateDir];
        ports = {
          authelia.port = 9091;
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
        assertion = ports.authelia.reverseProxy.enable;
        message = "Authelia needs to be reverse proxied as https is required.";
      }
    ];

    # Authelia secrets
    sops.secrets = {
      "authelia/jwtSecret" = {
        owner = config.services.authelia.instances.default.user;
        sopsFile = ./secrets.yaml;
      };
      "authelia/storageEncryptionKey" = {
        owner = config.services.authelia.instances.default.user;
        sopsFile = ./secrets.yaml;
      };
      "portunus/admin-pass" = {
        group = "auth";
        mode = "0440";
        sopsFile = ./secrets.yaml;
      };
    };

    # Auth group
    users.groups.auth = {};

    # Authelia service configuration
    services.authelia.instances.default = {
      enable = true;
      group = "auth";
      secrets = {
        jwtSecretFile = config.getSopsFile "authelia/jwtSecret";
        storageEncryptionKeyFile = config.getSopsFile "authelia/storageEncryptionKey";
      };
      environmentVariables = {
        AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE = config.getSopsFile "portunus/admin-pass";
        AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = config.getSopsFile "portunus/admin-pass";
      };
      settings = {
        server.address = "tcp://:${toString ports.authelia.port}";
        log.level = "info";
        storage.local.path = "${autheliaStateDir}/db.sqlite3";
        session.cookies = [
          rec {
            domain = getAddress {
              portName = "authelia";
            };
            authelia_url = getAddress {
              protocol = "https";
              portName = "authelia";
            };
          }
        ];
        access_control.default_policy = "one_factor";
        authentication_backend.ldap = {
          implementation = "custom";
          address = "ldaps://${cfg.domain}";
          base_dn = config.services.portunus.ldap.suffix;
          user = "uid=technical-admin,ou=users,${config.services.portunus.ldap.suffix}";
          users_filter = "(&(objectclass=person)({username_attribute}={input}))";
          groups_filter = "(isMemberOf=cn={dn},ou=groups)";
          attributes = {
            username = "uid";
            display_name = "cn";
            mail = "mail";
            group_name = "isMemberOf";
          };
        };
        notifier.smtp = {
          # we assume that the mailserver is accessable on the domain
          address = "smtp://${cfg.domain}:25";
          sender = "noreply@${cfg.domain}";
          username = "technical-admin";
        };
      };
    };

    # TLS
    services.porkbunAcme = {
      enable = true;
      inherit (cfg) domain;
    };
    # security.acme.certs."${cfg.domain}".extraDomainNames = [
    #   (toFullDomain {
    #     inherit serviceName hostName;
    #     portName = "portunus";
    #   })
    # ];
    users.users.portunus.extraGroups = ["acme"];

    # Portunus service configuration
    services.portunus = {
      enable = true;
      group = "auth";
      stateDir = portunusStateDir;
      domain = getAddress {
        portName = "portunus";
      };
      ldap = {
        tls = false; # we do it manually because limitations in nixpkgs module, see below in `environment`
        # build a valid RDN with only dc components of the reverse proxy domain
        suffix = pipe cfg.domain [
          (splitString ".")
          (map (e: "dc=${e}"))
          (concatStringsSep ",")
        ];
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
            posix_gid = 101;
          }
        ];
        users = [
          {
            login_name = "technical-admin";
            given_name = "Technical";
            family_name = "Administrator";
            email = "noreply@${cfg.domain}";
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
        acmeDirectory = config.security.acme.certs."${cfg.domain}".directory;
      in {
        PORTUNUS_SLAPD_TLS_CA_CERTIFICATE = config.security.pki.caBundle;
        PORTUNUS_SLAPD_TLS_CERTIFICATE = "${acmeDirectory}/cert.pem";
        PORTUNUS_SLAPD_TLS_DOMAIN_NAME = cfg.domain;
        PORTUNUS_SLAPD_TLS_PRIVATE_KEY = "${acmeDirectory}/key.pem";
      });
  };
}
