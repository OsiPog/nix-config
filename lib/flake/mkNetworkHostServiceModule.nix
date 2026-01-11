flake: {
  serviceName,
  withEnable ? true,
  withStateDir ? true,
}: networkModule: {lib, ...}: let
  inherit (flake.lib) mkModuleWithExtraMetaAttrs;
  inherit (lib) mkEnableOption mkMerge mkIf mkOption types;
  inherit (lib.lists) optional;
in
  mkMerge [
    {
      network.sharedModules = [
        ({
          config,
          name,
          ...
        }: let
          cfg = config.services.${serviceName};
        in {
          imports =
            [
              (mkModuleWithExtraMetaAttrs {
                  extraSpecialArgs = {inherit cfg;};
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
            ]
            # Ideally services should have an `enable` option which declares whether the service is active or not.
            ++ (optional withEnable {
              options.services.${serviceName}.enable = mkEnableOption "the ${serviceName} network service on ${name}";
            })
            # Most services are not stateless, so we have a state dir for it which is created with systemd.tmpfiles.rules. To create multiple
            # state directories extraStateDirs can be used.
            ++ (optional withStateDir {
              options.services.${serviceName} = {
                stateDir = mkOption {
                  description = "The directory where the ${serviceName} service needs to store its data.";
                  type = types.pathWith {absolute = true;};
                  default = "/var/lib/${serviceName}";
                };
                extraStateDirs = mkOption {
                  description = "Additional state directories to be created for the service.";
                  type = with types; listOf (pathWith {absolute = true;});
                  default = [];
                };
              };
              config = mkIf cfg.enable {
                stateDirs = [cfg.stateDir] ++ cfg.extraStateDirs;
              };
            });
        })
      ];
    }
  ]
