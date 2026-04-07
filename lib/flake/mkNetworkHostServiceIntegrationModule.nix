flake: {
  integrationName,
  serviceName,
  role, # one of 'client', 'server', 'peer'
}: provide: {lib, ...}: let
  inherit (builtins) filter length head;
  inherit (lib) types pipe mkOption mkEnableOption;
in {
  network.sharedModules = [
    ({
      nixosConfig,
      name,
      config,
      ...
    }: let
      cfg = config.services.${serviceName};
    in {
      imports = [
        {
          config.services.${serviceName}.${integrationName} = {inherit provide;};
        }
        {
          options.services.${serviceName}.${integrationName} = mkOption {
            type = types.submodule ({config, ...}: {
              options = {
                enable = mkEnableOption "the ${integrationName} integration";
                id = mkOption {
                  description = "ID used to match clients with servers and peers with peers.";
                  type = types.str;
                  default = integrationName;
                };
                role = mkOption {
                  description = "Role this service has in the integration relationship.";
                  type = types.enum ["client" "server" "peer"];
                  readOnly = true;
                  default = role;
                };
                require = mkOption {
                  description = "Data provided by peers. For role \"client\" this is just the 'provide' of the server. For \"server\" and \"peer\" this is a list of 'provide'.";
                  readOnly = true;
                  default = pipe nixosConfig.network.integrationData [
                    # 1. filter all integration data to relevant data (same integration name, same id, correct role)
                    (filter (data:
                      data.name
                      == integrationName
                      && data.id == config.id
                      && data.role
                      == (
                        if config.role == "server"
                        then "client"
                        else if config.role == "client"
                        then "server"
                        else "peer"
                      )))
                    # 2. map to provide
                    (map (e: e.provide))
                    # 3. bring provide into correct format
                    (data:
                      if config.role == "client"
                      then
                        if length data > 1
                        then throw "${name}: ${serviceName}: ${integrationName}: found multiple servers with ID \"${config.id}\"."
                        else if length data == 1
                        then (head data).server
                        else null
                      else data)
                  ];
                };

                # INTERFACE
                provide = let
                  provideOptions = {
                    ldap = {
                      server = {
                        baseDN = mkOption {
                          description = "The base DN of the LDAP directory.";
                          type = types.str;
                        };
                        adminUser = mkOption {
                          description = "The DN of the LDAP admin user.";
                          type = types.str;
                        };
                        searchUserDN = mkOption {
                          description = "The DN of the LDAP search user used by client services.";
                          type = types.str;
                        };
                      };
                      client = {
                        group = mkOption {
                          description = "The LDAP group to create for users of this service.";
                          type = types.str;
                        };
                      };
                    };
                    oidc = {
                      client = {
                        clientId = mkOption {
                          description = "The OIDC client ID for this service.";
                          type = types.str;
                        };
                      };
                    };
                    mail = {
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
                in
                  if (provideOptions ? integrationName)
                  then provideOptions.${integrationName}.${config.role} or {}
                  else throw "mkNetworkIntegrationModule: \"${integrationName}\" does not have a provide options set.";
              };
            });
          };
        }
      ];
    })
  ];
}
