{
  lib,
  config,
  flake,
  options,
  ...
}: let
  inherit (flake.lib) nixosHostNames;
  inherit (lib) mkOption types;
  inherit (lib.attrsets) optionalAttrs;

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
    description = "Function that resolves to an address.";
  };

  secretOption = mkOption {
    description = "A sops secret";
    type = options.sops.secrets.type.nestedTypes.elemType;
  };

  integrationsOptions = {
    ldap = mkIntegration {
      server = {
        address = addressOption;
        baseDN = mkOption {
          description = "The base DN of the LDAP directory.";
          type = types.str;
        };
        adminUser = {
          dn = mkOption {
            description = "The DN of the LDAP admin user.";
            type = types.str;
          };
          secret = secretOption;
        };

        searchUser = {
          dn = mkOption {
            description = "The DN of the LDAP search user used by client services.";
            type = types.str;
          };
          secret = secretOption;
        };
      };
      clients = {
        group = mkOption {
          description = "The LDAP group to create for users of this service.";
          type = types.str;
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
