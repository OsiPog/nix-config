{
  config,
  lib,
  flake,
  hostName,
  pkgs,
  ...
}: let
  inherit (builtins) concatStringsSep mapAttrs getAttr;
  inherit (lib) mkIf pipe mkForce mkMerge;
  inherit (lib.strings) splitString;

  inherit (flake.lib) mkNetworkHostServiceModule mkSharedSecrets mkGroupsFromSecretsWithMembers mapMerge;

  serviceName = "lldap";
  networkCfg = config.network;
  hostCfg = config.network.hosts.${hostName};
  cfg = hostCfg.services.${serviceName};
  ports = hostCfg.ports;

  ldapServer = cfg.provide.ldap-server;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({
      name,
      networkLib,
      ...
    }: {
      configEnable = {
        ports = {
          lldap.port = 17170;
          ldaps = {
            port = 6360;
            reverseProxy.method = "stream";
          };
        };
      };
      configService.provide.ldap-server = rec {
        secrets =
          mkSharedSecrets [
            users.admin.secretName
            users.search.secretName
            users.manage.secretName
          ]
          ./secrets.yaml;
        address = networkLib.getAddress {
          hostName = name;
          portName = "ldaps";
        };
        baseDN = pipe (address "domain") [
          (splitString ".")
          (map (e: "dc=${e}"))
          (concatStringsSep ",")
        ];
        users = {
          admin = {
            dn = "admin";
            secretName = "lldap/admin-pass";
          };
          search = {
            dn = "search-user";
            secretName = "lldap/search-pass";
          };
          manage = {
            dn = "manager";
            secretName = "lldap/manager-pass";
          };
        };
        attributes = {
          email = "mail";
          uid = "uid";
          password = "password";
          icon = "avatar";
          memberof = "memberof";
        };
      };
    }))

    flake.nixosModules.porkbunAcme
    flake.nixosModules.lldapBootstrap
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
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

      sops.secrets = ldapServer.secrets;

      # TLS
      services.porkbunAcme = {
        enable = true;
        domain = ldapServer.address "domain";
      };

      users.users.lldap = {
        group = "lldap";
        isSystemUser = true;

        # Give lldap user access to ACME certificates
        extraGroups = ["acme"];
      };

      users.groups = {lldap = {};} // (mkGroupsFromSecretsWithMembers ldapServer.secrets ["lldap"]);

      # LLDAP service configuration
      services.lldap = {
        enable = true;
        settings = {
          verbose = true;
          http_host = "0.0.0.0";
          http_port = ports.lldap.port;
          ldap_base_dn = ldapServer.baseDN;
          ldap_user_dn = ldapServer.users.admin.dn;
          ldap_user_pass_file = config.getSopsFile ldapServer.users.admin.secretName;
          database_url = "sqlite://${cfg.stateDir}/users.db?mode=rwc";
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
          cleanup = {
            enable = true;
            keepUsers = true;
            keepGroupMembership = true;
          };
          users.configs = {
            "${ldapServer.users.search.dn}" = {
              email = "search@${ldapServer.address "domain"}";
              password_file = config.getSopsFile ldapServer.users.search.secretName;
              groups = ["lldap_strict_readonly"];
            };
            "${ldapServer.users.manage.dn}" = {
              email = "manage@${ldapServer.address "domain"}";
              password_file = config.getSopsFile ldapServer.users.manage.secretName;
              groups = ["lldap_password_manager"];
            };
          };
        };
      };

      systemd = {
        services.lldap.serviceConfig.DynamicUser = mkForce false;
        # Ensure state directory is owned by lldap
        tmpfiles.rules = [
          "d /var/lib/lldap 0750 lldap lldap -"
        ];
      };
    }

    # implement ldap clients

    (let
      clients = cfg.require.ldap-clients;
    in {
      sops = mapMerge clients (e: {secrets = e.secrets;});

      users = mapMerge clients (e: {
        groups = mkGroupsFromSecretsWithMembers e.secrets ["lldap"];
      });

      services = mapMerge clients (e: {
        lldap.bootstrap = {
          groups.configs = e.groups;
          users = {
            schema =
              mapAttrs (_: attribute: {
                attributeType = getAttr attribute.dataType {
                  string = "STRING";
                  integer = "INTEGER";
                  boolean = throw "Boolean type is not implemented by lldap use integer instead";
                  jpeg = "JPEG";
                  datetime = "DATETIME";
                };
              })
              e.extraUserAttributes;
            configs =
              mapAttrs (_: user: {
                displayName = user.display;
                password_file = config.getSopsFile user.secretName;
                email = user.email;
              })
              e.users;
          };
        };
      });
    })
  ]);
}
