{
  config,
  hostName,
  lib,
  pkgs,
  flake,
  ...
}: let
  inherit (lib) mkMerge mkIf mkOption mkDefault;
  inherit (config.lib.network) getIntegrationVariables serviceEnabledAnywhere;
  inherit (flake.lib) mkNetworkHostServiceIntegrationModule;

  inherit
    (getIntegrationVariables "ldap" ["mailserver" "authelia"])
    integrationName
    integratedServices
    networkCfg
    hostSrvs
    serviceWithIntegrationEnable
    integratedServiceEnable
    ;
in {
  imports = [
    (mkNetworkHostServiceIntegrationModule {
        inherit integratedServices integrationName;
        serviceName = "lldap";
        portName = "ldaps";
        protocol = "ldaps";
      } ({cfg, ...}: {
        optionsIntegration = {
          baseDN = mkOption {
            description = "Read only option of the base dn of the ldap server.";
            readOnly = true;
            default = networkCfg.hosts.${cfg.host}.services.lldap.ldap.baseDN;
          };
          searchUserDN = mkOption {
            description = "dn of the search user";
            readOnly = true;
            default = "uid=search-user,ou=people,${cfg.baseDN}";
          };
        };
      }))
    flake.nixosModules.lldapBootstrap
  ];

  config = mkIf networkCfg.enable (mkMerge [
    # --- SHARED
    # define the search users secret file so that all services that need it have access to it
    (mkIf (hostSrvs.lldap.enable || integratedServiceEnable) {
      sops.secrets."ldap/search-user-pass" = {
        sopsFile = ./secrets.yaml;
        group = "ldap-search";
        mode = "0440";
      };

      users.groups.ldap-search = {};
    })

    # LDAP SERVER
    #
    # --- LLDAP
    # Add the search user to the seeded users
    (mkIf hostSrvs.lldap.enable {
      users.users.lldap.extraGroups = ["ldap-search"];
      services.lldap.bootstrap = {
        enable = true;
        users.configs.search-user = {
          email = "search-user@example.com";
          password_file = config.getSopsFile "ldap/search-user-pass";
          groups = [
            "lldap_password_manager" # has rw permissions on users
          ];
        };
      };
    })

    # LDAP CLIENTS

    # --- AUTHELIA
    (mkIf (serviceWithIntegrationEnable "authelia") (let
      inherit (hostSrvs.authelia.integrations) ldap;
    in {
      users.users.${config.services.authelia.instances.default.user}.extraGroups = ["ldap-search"];
      services.authelia.instances.default = {
        environmentVariables = {
          AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE = config.getSopsFile "ldap/search-user-pass";
        };
        settings = {
          authentication_backend = {
            refresh_interval = mkDefault "1m"; # interval to query for user data changes
            ldap = {
              implementation = "lldap";
              address = ldap.address;
              base_dn = ldap.baseDN;
              user = ldap.searchUserDN;
            };
          };
        };
      };
    }))

    # --- MAILSERVER
    # Create a group to only allow certain users to access mailserver. Also, add a read-only attribute for mail aliases
    (mkIf (hostSrvs.lldap.enable && (serviceEnabledAnywhere "mailserver")) {
      services.lldap.bootstrap = {
        enable = true;
        groups.configs.email = {};
        users = {
          schema.mail-aliases = {
            attributeType = "STRING";
            isEditable = false;
            isList = true;
            isVisible = true;
          };
        };
      };
    })
    # Configure the mailserver to use ldap
    (mkIf (serviceWithIntegrationEnable "mailserver") (let
      inherit (hostSrvs.mailserver.integrations) ldap;

      usersFilter = placeholder: "(&(|(mail=${placeholder})(mail-aliases=${placeholder}))(memberof=cn=email,ou=groups,${ldap.baseDN}))";
    in {
      users.users.${config.services.postfix.user}.extraGroups = ["ldap-search"];

      mailserver.ldap = {
        enable = true;
        searchBase = ldap.baseDN;
        uris = [ldap.address];
        bind = {
          dn = ldap.searchUserDN;
          passwordFile = config.getSopsFile "ldap/search-user-pass";
        };
        postfix = {
          filter = usersFilter "%s";
          uidAttribute = "uid";
          mailAttribute = "mail";
        };
        dovecot.passFilter = usersFilter "%{user}";
      };
    }))
  ]);
}
