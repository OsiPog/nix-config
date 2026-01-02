{
  config,
  hostName,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkMerge mkIf mkOption mkEnableOption foldl';
  inherit (lib.lists) findFirst;
  inherit (lib.attrsets) genAttrs;
  inherit (config.lib.network) getAddress allPorts;

  networkCfg = config.network;
  hostCfg = networkCfg.hosts.${hostName};
  hostSrvs = hostCfg.services;

  integratedServices = ["mailserver" "authelia"];

  integratedServiceEnable = foldl' (acc: elem: acc || hostCfg.services.${elem}.enable) false integratedServices;

  ldapsAddress = getAddress {
    protocol = "ldaps";
    portName = "ldaps";
  };

  searchUserDN = baseDN: "uid=search-user,ou=users,${baseDN}";

  usersFilter = baseDN: attr: placeholder: group: "(&(objectclass=person)(${attr}=${placeholder})${
    if group != null
    then groupsFilter baseDN group
    else ""
  })";
  groupsFilter = baseDN: placeholder: "(isMemberOf=cn=${placeholder},ou=groups,${baseDN})";
in
  mkMerge [
    {
      network.sharedModules = [
        ({...}: {
          options.services = genAttrs integratedServices (_: {
            integrations.ldaps = mkOption {
              description = "ldaps server integration";
              type = lib.types.submodule (integrationModule: {
                options = {
                  enable = mkEnableOption "ldaps server integration";
                  host = mkOption {
                    description = "The host the ldaps server is running on.";
                    type = with lib.types; nullOr str;
                  };
                  portunusCfg = mkOption {
                    description = "Portunus configuration options set on the ldaps host.";
                    readOnly = true;
                    default = networkCfg.hosts.${integrationModule.config.host}.services.portunus;
                  };
                };
                config = mkIf integrationModule.config.enable {
                  host = (findFirst (p: p.portName == "ldaps") (throw "LDAPS Integration: ldaps port it not defined on any host.") allPorts).hostName;
                };
              });
              default = {};
            };
          });
        })
      ];
    }

    # --- SHARED
    # define the search users secret file so that all services that need it have access to it
    (mkIf (networkCfg.enable && (hostSrvs.portunus.enable || integratedServiceEnable)) {
      sops.secrets."portunus/search-pass" = {
        sopsFile = ./secrets.yaml;
        group = "portunus-search";
        mode = "0440";
      };

      users.groups.portunus-search = {};
    })

    # LDAP SERVER
    #
    # --- PORTUNUS
    # Add the search user to the seeded users
    (mkIf (networkCfg.enable && hostSrvs.portunus.enable) {
      # TODO: for some reason the portunus user cannot read the secret even though the group an permissions are correct
      sops.secrets."portunus/search-pass".owner = config.services.portunus.user;

      users.users.${config.services.portunus.user}.extraGroups = ["portunus-search"];
      services.portunus.seedSettings = {
        groups = [
          {
            name = "search-team";
            long_name = "Search Users";
            members = ["search-user"];
            permissions.ldap.can_read = true;
          }
          # only people in the email group may login with email servers
          {
            name = "email";
            long_name = "Email";
            members = [];
          }
        ];
        users = [
          {
            login_name = "search-user";
            given_name = "Search";
            family_name = "User";
            password.from_command = ["cat" (config.getSopsFile "portunus/search-pass")];
          }
        ];
      };
    })

    # LDAP CLIENTS

    # --- AUTHELIA
    (mkIf (networkCfg.enable && hostSrvs.authelia.enable && hostSrvs.authelia.integrations.ldaps.enable) {
      users.users.${config.services.authelia.instances.default.user}.extraGroups = ["portunus-search"];
      services.authelia.instances.default = {
        environmentVariables = {
          AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE = config.getSopsFile "portunus/search-pass";
        };
        settings = {
          authentication_backend.ldap = rec {
            implementation = "custom";
            address = ldapsAddress;
            base_dn = hostSrvs.authelia.integrations.ldaps.portunusCfg.ldap.baseDN;
            user = searchUserDN base_dn;
            users_filter = usersFilter base_dn "{username_attribute}" "{input}" null;
            groups_filter = groupsFilter base_dn "{dn}";
            attributes = {
              username = "uid";
              display_name = "cn";
              mail = "mail";
              group_name = "isMemberOf";
            };
          };
        };
      };
    })

    # --- MAILSERVER
    (mkIf (networkCfg.enable && hostSrvs.mailserver.enable && hostSrvs.mailserver.integrations.ldaps.enable) {
      users.users.${config.services.postfix.user}.extraGroups = ["portunus-search"];

      mailserver.ldap = rec {
        enable = true;
        searchBase = hostSrvs.mailserver.integrations.ldaps.portunusCfg.ldap.baseDN;
        uris = [ldapsAddress];
        bind = {
          dn = searchUserDN searchBase;
          passwordFile = config.getSopsFile "portunus/search-pass";
        };
        postfix = {
          filter = usersFilter searchBase "mail" "%s" "email";
          uidAttribute = "uid";
          mailAttribute = "mail";
        };
        dovecot.passFilter = usersFilter searchBase "mail" "%{user}" "email";
      };
    })
  ]
