flake: {serviceName}: networkModule: {lib, ...}: let
  inherit (builtins) attrNames;
  inherit (flake.lib) mkModuleWithExtraMetaAttrs;
  inherit (lib) mkEnableOption mkIf mkOption types;
  inherit (lib.attrsets) mapAttrs' genAttrs;
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
            extraSpecialArgs = {inherit cfg;};
            mapExtraMetaAttr = name: content:
              if name == "optionsService"
              then {options.services.${serviceName} = content;}
              else if name == "configEnable"
              then {config = mkIf cfg.enable content;}
              else if name == "configService"
              then {config.services.${serviceName} = content;}
              else if name == "integrationsEnable"
              then {
                config = {
                  # maps integrationEnable = {ldap.server = {...}} to config.network.integrations.ldap.<id>.server = {...}
                  _integrations =
                    mapAttrs' (name: value: {
                      inherit name;
                      value = {
                        ${cfg.integrations.${name}.id} = mkIf (cfg.enable && ((cfg.integrations.${name} or null) != null) && cfg.integrations.${name}.enable) value;
                      };
                    })
                    content;

                  # When enable is checked it the option set needs to have the default value, thats applied here
                  services.${serviceName}.integrations = genAttrs (attrNames content) (_: {});
                };
              }
              else null;
          }
          networkModule)

        # options every network service has
        {
          options.services.${serviceName} = {
            enable = mkEnableOption "the ${serviceName} network service on ${name}";
            integrations = mkOption {
              description = "Integrations to integrate with other services on the network";
              default = {};
              type = types.attrsOf (types.submodule ({name, ...}: {
                options = {
                  enable = mkEnableOption "the ${name} integration";
                  id = mkOption {
                    description = "ID used to match clients with servers and peers with peers.";
                    type = types.str;
                    default = "default";
                  };
                };
              }));
            };
          };
        }
      ];
    })
  ];
}
