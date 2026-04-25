{
  lib,
  config,
  flake,
  options,
  ...
}: let
  inherit (builtins) replaceStrings;
  inherit (flake.lib) nixosHostNames;
  inherit (lib) mkOption types mkEnableOption;
  inherit (lib.attrsets) optionalAttrs genAttrs;

  mkIntegration = {
    server ? null,
    clients ? null,
  }:
    mkOption {
      type = types.attrsOf (types.submodule {
        options =
          {}
          // optionalAttrs (server != null) {
            inherit server;
          }
          // optionalAttrs (clients != null) {
            clients = mkOption {
              type = types.listOf (types.submodule {options = clients;});
              description = "Data provided by each client registered under this ID.";
              default = [];
            };
          };
      });
      default = {};
    };

  addressOption = mkOption {
    description = "The function returned by calling getAddress with a single attrset.";
  };

  secretOption = mkOption {
    description = "A sops secret passed to sops.secrets";
    type = types.mergeTypes types.attrs (types.attrsOf (types.submodule ({config, ...}: {
      options = {
        key = mkOption {
          default = "The key to be looked up in the secrets file.";
          type = types.str;
        };
        group = mkOption {
          readOnly = true;
          default = "${replaceStrings ["/"] ["-"] config.key}";
        };
        mode = mkOption {
          readOnly = true;
          default = "0440";
        };
      };
    })));
  };

  integrationsOptions = {
    ldap = let
      mkLdapUser = desc:
        mkOption {
          description = desc;
          type = types.submodule {
            options = {
              dn = mkOption {
                description = "The DN of the user without the baseDN.";
                type = types.str;
              };
              secret = secretOption;
            };
          };
        };
    in
      mkIntegration {
        server = {
          address = addressOption;
          baseDN = mkOption {
            description = "The base DN of the LDAP directory.";
            type = types.str;
          };
          adminUser = mkLdapUser "user with admin permissions";
          searchUser = mkLdapUser "user with search permissions";
          managerUser = mkLdapUser "user with search and edit permissions";
        };
        clients = {
          createGroups = mkOption {
            description = "The LDAP groups to create.";
            default = {};
            type = types.attrsOf types.attrs; # currently no sub options available, so just if its defined, group will be created
          };
          createUsers = mkOption {
            description = "The LDAP users to create";
            default = {};
            type = types.attrsOf (types.submodule {
              options = {
                display = mkOption {
                  description = "Display name";
                  type = types.nullOr types.str;
                  default = null;
                };
                email = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                };
                secret = secretOption;
              };
            });
          };
          createUserAttributes = mkOption {
            description = "Additional user attributes to create";
            default = {};
            type = types.attrsOf (types.submodule {
              options = {
                dataType = mkOption {
                  type = types.enum ["string" "integer" "boolean" "image" "datetime"];
                };
                editable = mkEnableOption "the attribute to be editable by users";
                multiple = mkEnableOption "the attribute to have multiple values";
                visible = mkEnableOption "the attribute to be visible to users";
              };
            });
          };
        };
      };

    oidc = mkIntegration {
      server = {
        issuerUrl = mkOption {
          description = "The OIDC issuer URL used by clients for discovery.";
          type = types.str;
        };
      };
      clients = {
        clientId = mkOption {
          description = "The OIDC client ID for this service.";
          type = types.str;
        };
      };
    };

    mail = mkIntegration {
      server = {
        notifierMail = mkOption {
          description = "Mail address of the notifier account used to send system notifications.";
          type = types.str;
        };
        displayName = mkOption {
          description = "Display name of the mail sender shown to recipients.";
          type = types.str;
        };
      };
    };
  };
in {
  imports = map (hostName: {network.integrations = config.network.hosts.${hostName}._integrations;}) nixosHostNames;
  options.network.integrations = integrationsOptions;
  config.network.sharedModules = [
    ({...}: {
      options._integrations = mkOption {
        description = "Internal option for gathering integration data per host. Do not use. Use `network.integrations` directly.";
        # type = handled by network.integrations for slightly nicer error messages
        default = {};
      };
    })
  ];
}
