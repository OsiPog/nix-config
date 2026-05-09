flake: {serviceName}: networkModule: {
  lib,
  config,
  hostName,
  ...
}: let
  inherit (builtins) mapAttrs;
  inherit (flake.lib) mkModuleWithExtraMetaAttrs;
  inherit (lib) mkEnableOption mkIf mkOption types mkMerge;
  inherit (lib.attrsets) optionalAttrs mapAttrsToList;

  networkCfg = config.network;
in {
  network.sharedModules = [
    ({
      config,
      name,
      ...
    }: let
      cfg = config.services.${serviceName};
    in {
      imports = [
        (mkModuleWithExtraMetaAttrs {
            extraSpecialArgs = {
              inherit cfg;
              inherit name; # I think because we use imports instead of directly through sharedModules we lose the `name` extra argument.
            };
            mapExtraMetaAttr = name: content:
              if name == "optionsService"
              then {options.services.${serviceName} = content;}
              else if name == "configEnable"
              then {config = mkIf cfg.enable content;}
              else if name == "configService"
              then {config.services.${serviceName} = content;}
              else null;
          }
          networkModule)

        # options every network service has
        ({...}: {
          options.services.${serviceName} = {
            enable = mkEnableOption "the ${serviceName} network service on ${name}";
            integrations = mkOption {
              description = "Integrations to integrate with other services on the network";
              default = {};
              type = types.attrsOf (types.submodule ({
                name,
                config,
                ...
              }: let
                integrationName = name;
                integrationCfg = config;
              in {
                options = let
                  scopedName = name: "integrations/${integrationName}/${integrationCfg.id}/${serviceName}/${name}";
                in {
                  enable = mkEnableOption "the ${name} integration";
                  id = mkOption {
                    description = "ID used to match clients with servers.";
                    type = types.str;
                    default = "default";
                  };
                  local = {
                    server = mkOption {
                      description = "Define server data for the integration matching the specified ID.";
                      type = types.nullOr types.attrs;
                      default = null;
                    };
                    clients = mkOption {
                      description = "Define a list of clients data for the integration matching the specified ID.";
                      type = types.listOf types.attrs;
                      default = [];
                    };
                    client = mkOption {
                      description = "Alias for clients = [ <this> ]";
                      type = types.nullOr types.attrs;
                      default = null;
                    };
                  };
                  remote = {
                    server = mkOption {
                      description = "Server data in the integration matching the specified ID.";
                      type = types.nullOr types.attrs;
                      default = networkCfg.integrations.${integrationName}.${integrationCfg.id}.server;
                      readOnly = true;
                    };
                    clients = mkOption {
                      description = "List of clients data in the integration matching the specified ID.";
                      type = types.listOf types.attrs;
                      default = networkCfg.integrations.${integrationName}.${integrationCfg.id}.clients;
                      readOnly = true;
                    };
                  };
                  # Used in `mkMerge` to quickly register secrets defined in `remote` block of integrations into the current system and giving specifc users access to them
                  mkRegisterIntegrationSecretsConfig = {
                    secrets, # attrs of secrets in the form of sops.secrets.<name>.this
                    users, # list of usernames
                  }:
                    mkMerge (mapAttrsToList (name: secret: {
                        sops.secrets.${scopedName name} = secret;
                        users.groups.${secret.group}.members = users;
                      })
                      secrets);
                  # Used to get the integration secret file path
                  getSopsFile = name: config.getSopsFile (scopedName name);
                };
                # Apply aliases
                config.local = let
                  inherit (integrationCfg.local) client;
                in {
                  clients = mkIf (client != null) [client];
                };
              }));
            };
          };
          config._integrations = mkIf (cfg.enable) (
            mapAttrs (integrationName: integrationCfg: {
              ${integrationCfg.id} = mkIf (integrationCfg.enable) (
                let
                  inherit (integrationCfg.local) server clients;
                in
                  {
                    clients = mkIf (clients != []) clients;
                  }
                  // (optionalAttrs (server != null) {
                    inherit server;
                  })
              );
            })
            cfg.integrations
          );
        })
      ];
    })
  ];
}
