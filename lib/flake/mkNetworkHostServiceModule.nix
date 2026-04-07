flake: {serviceName}: networkModule: {lib, ...}: let
  inherit (flake.lib) mkModuleWithExtraMetaAttrs;
  inherit (lib) mkEnableOption mkIf mkOption types;
  inherit (lib.attrsets) mapAttrs';
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
                # maps integrationEnable = {ldap.server = {...}} to config.network.hosts.<name>.integrations.ldap.<id>.server = {...}
                config.integrations =
                  mapAttrs' (name: value: {
                    inherit name;
                    value.${cfg.integrations.${name}.id} = mkIf (cfg.integrations.${name}.enable) value;
                  })
                  content;
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
