{
  config,
  lib,
  flake,
  ...
}: let
  inherit (builtins) concatStringsSep getAttr mapAttrs;
  inherit (lib) mkIf pipe mkForce mkMerge;
  inherit (lib.strings) splitString;
  inherit (lib.attrsets) mapAttrs';

  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getAddress getServiceVariables;

  inherit
    (getServiceVariables "lldap")
    serviceName
    networkCfg
    cfg
    ports
    stateDir
    ;

  ldapServer = cfg.integrations.ldap.local.server;
  ldapClients = cfg.integrations.ldap.remote.clients;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({name, ...}: {
      configEnable = {
        ports = {
          lldap.port = 17170;
          ldaps = {
            port = 6360;
            reverseProxy.method = "stream";
          };
        };
      };
      configService.integrations.ldap.local.server = rec {
        address = getAddress {
          portName = "ldaps";
          hostName = name;
        };
        baseDN = pipe (address "domain") [
          (splitString ".")
          (map (e: "dc=${e}"))
          (concatStringsSep ",")
        ];
        adminUser = {
          dn = "admin";
          secret = {
            sopsFile = ./secrets.yaml;
            key = "lldap/admin-pass";
          };
        };
        searchUser = {
          dn = "search-user";
          secret = {
            sopsFile = ./secrets.yaml;
            key = "lldap/search-pass";
          };
        };
        managerUser = {
          dn = "manager";
          secret = {
            sopsFile = ./secrets.yaml;
            key = "lldap/manager-pass";
          };
        };
      };
    }))

    flake.nixosModules.porkbunAcme
    flake.nixosModules.lldapBootstrap
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    # register secrets with read access for the lldap user
    (cfg.integrations.ldap.mkRegisterIntegrationSecretsConfig {
      secrets = {
        adminUserPass = ldapServer.adminUser.secret;
        searchUserPass = ldapServer.searchUser.secret;
        managerUserPass = ldapServer.managerUser.secret;
      };
      users = ["lldap"];
    })

    {
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

      # TLS
      services.porkbunAcme = {
        enable = true;
        domain = ldapServer.address "domain";
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
          ldap_base_dn = ldapServer.baseDN;
          ldap_user_dn = ldapServer.adminUser.dn;
          ldap_user_pass_file = cfg.integrations.ldap.getSopsFile "adminUserPass";
          database_url = "sqlite://${stateDir}/users.db?mode=rwc";
          force_ldap_user_pass_reset = "always";
          ldaps_options = let
            acmeDirectory = config.security.acme.certs.${ldapServer.address "domain"}.directory;
          in {
            enabled = true;
            port = ports.ldaps.port;
            cert_file = "${acmeDirectory}/cert.pem";
            key_file = "${acmeDirectory}/key.pem";
          };
        };
        bootstrap = {
          enable = true;
          users.configs = {
            ${ldapServer.searchUser.dn} = {
              email = "search-user@example.com";
              password_file = cfg.integrations.ldap.getSopsFile "searchUserPass";
              groups = [
                "lldap_strict_readonly"
              ];
            };
            ${ldapServer.managerUser.dn} = {
              email = "manager-user@example.com";
              password_file = cfg.integrations.ldap.getSopsFile "managerUserPass";
              groups = [
                "lldap_password_manager" # has rw permissions on users
              ];
            };
          };
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
          "d ${stateDir} 0750 lldap lldap -"
        ];
      };
    }

    # LDAP INTEGRATION
    (mkIf (cfg.integrations.ldap.enable) (pipe ldapClients [
      (map ({
        createGroups,
        createUsers,
        createUserAttributes,
      }:
        (
          cfg.integrations.ldap.mkRegisterIntegrationSecretsConfig {
            secrets =
              mapAttrs' (name: {secret, ...}: {
                name = "${name}UserPass";
                value = secret;
              })
              createUsers;
            users = ["lldap"];
          }
        )
        // {
          services.lldap.bootstrap = {
            groups.configs = createGroups;
            users = {
              schemas =
                mapAttrs (_: {
                  dataType,
                  editable,
                  multiple,
                  visible,
                }: {
                  attributeType = getAttr dataType {
                    string = "STRING";
                    integer = "INTEGER";
                    boolean = throw "Type boolean is not implemented in LLDAP.";
                    jpeg = "JPEG";
                    datetime = "DATETIME";
                  };
                  isEditable = editable;
                  isList = multiple;
                  isVisible = visible;
                })
                createUserAttributes;
              configs =
                mapAttrs (name: {
                  display,
                  email,
                  ...
                }: {
                  inherit email;
                  displayName = display;
                  password_file = cfg.integrations.ldap.getSopsFile "${name}UserPass";
                })
                createUsers;
            };
          };
        }))
    ]))
  ]);
}
