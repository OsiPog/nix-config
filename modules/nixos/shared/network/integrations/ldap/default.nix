{
  config,
  hostName,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkMerge mkIf mkOption mkEnableOption foldl' mkDefault;
  inherit (lib.lists) findFirst;
  inherit (lib.attrsets) genAttrs;
  inherit (config.lib.network) getAddress allPorts;

  networkCfg = config.network;
  hostCfg = networkCfg.hosts.${hostName};
  hostSrvs = hostCfg.services;

  integratedServices = ["mailserver" "authelia"];

  integratedServiceEnable = foldl' (acc: elem: acc || (hostCfg.services.${elem}.enable && hostCfg.services.${elem}.integrations.ldap.enable)) false integratedServices;
in
  mkMerge [
    {
      network.sharedModules = [
        ({...}: {
          options.services = genAttrs integratedServices (_: {
            integrations.ldap = mkOption {
              description = "ldap server integration";
              type = lib.types.submodule (integrationModule: let
                defaultHost = (findFirst (p: p.portName == "ldaps") (throw "LDAP Integration: ldaps port it not defined on any host.") allPorts).hostName;

                portunusCfg = networkCfg.hosts.${integrationModule.config.host}.services.portunus;

                inherit (portunusCfg.ldap) baseDN;

                getGroupsFilter = placeholder: "(isMemberOf=cn=${placeholder},ou=groups,${baseDN})";
                getUsersFilter = attr: placeholder: group: "(&(objectclass=person)(${attr}=${placeholder})${
                  if group != null
                  then getGroupsFilter group
                  else ""
                })";
                address = getAddress {
                  portName = "ldaps";
                  protocol = "ldaps";
                  hostName = integrationModule.config.host;
                };
              in {
                options = {
                  enable = mkEnableOption "ldap server integration";
                  host = mkOption {
                    description = "The host the ldap server is running on.";
                    type = lib.types.str;
                  };
                  baseDN = mkOption {
                    description = "Read only option of the base dn of the ldap server.";
                    readOnly = true;
                    default = baseDN;
                  };
                  searchUserDN = mkOption {
                    description = "dn of the search user";
                    readOnly = true;
                    default = "uid=search-user,ou=users,${baseDN}";
                  };
                  address = mkOption {
                    description = "Read only option of the ldap address";
                    readOnly = true;
                    default = address;
                  };
                  getUsersFilter = mkOption {
                    description = "Read only option that contains a function that returns a users filter with an optional group filter";
                    readOnly = true;
                    default = getUsersFilter;
                  };
                  getGroupsFilter = mkOption {
                    description = "Read only option that contains a function that returns a group filter";
                    readOnly = true;
                    default = getGroupsFilter;
                  };
                };
                config = mkIf integrationModule.config.enable {
                  host = mkDefault defaultHost;
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
    (mkIf (networkCfg.enable && hostSrvs.authelia.enable && hostSrvs.authelia.integrations.ldap.enable) (let
      inherit (hostSrvs.authelia.integrations) ldap;
    in {
      users.users.${config.services.authelia.instances.default.user}.extraGroups = ["portunus-search"];
      services.authelia.instances.default = {
        environmentVariables = {
          AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE = config.getSopsFile "portunus/search-pass";
        };
        settings = {
          authentication_backend = {
            # password reset and change does not work with portunus ldap, search user can only have read perms
            password_reset.disable = true;
            password_change.disable = true;

            ldap = {
              implementation = "custom";
              address = ldap.address;
              base_dn = ldap.baseDN;
              user = ldap.searchUserDN;
              users_filter = ldap.getUsersFilter "{username_attribute}" "{input}" null;
              groups_filter = ldap.getGroupsFilter "{dn}";
              attributes = {
                username = "uid";
                display_name = "cn";
                mail = "mail";
                group_name = "isMemberOf";
              };
            };
          };
        };
      };
    }))

    # --- MAILSERVER
    (mkIf (networkCfg.enable && hostSrvs.mailserver.enable && hostSrvs.mailserver.integrations.ldap.enable) (let
      inherit (hostSrvs.mailserver.integrations) ldap;
    in {
      users.users.${config.services.postfix.user}.extraGroups = ["portunus-search"];

      mailserver.ldap = {
        enable = true;
        searchBase = ldap.baseDN;
        uris = [ldap.address];
        bind = {
          dn = ldap.searchUserDN;
          passwordFile = config.getSopsFile "portunus/search-pass";
        };
        postfix = {
          filter = ldap.getUsersFilter "mail" "%s" "email";
          uidAttribute = "uid";
          mailAttribute = "mail";
        };
        dovecot.passFilter = ldap.getUsersFilter "mail" "%{user}" "email";
      };
    }))
  ]
