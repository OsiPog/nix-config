flake: {
  serviceName,
  withEnable ? true,
  withStateDir ? true,
}: networkModule: {lib, ...}: let
  inherit (builtins) foldl' elem attrNames filter;
  inherit (lib) mkEnableOption mkMerge mkIf mkOption types;
  inherit (lib.lists) optional;
  inherit (lib.attrsets) recursiveUpdate;
in
  mkMerge [
    {
      network.sharedModules = [
        (moduleArgs: let
          cfg = moduleArgs.config.services.${serviceName};
          evaluated =
            if networkModule != null
            then networkModule (moduleArgs // {inherit cfg;})
            else {};

          metaAttrNames = [
            "imports"
            "options"
            "config"
            "optionsService"
            "configEnable"
            "configService"
          ];

          configIsRoot = filter (name: ! (elem name metaAttrNames)) (attrNames evaluated) != [];
        in {
          imports =
            [
              {
                imports = evaluated.imports or [];

                options = foldl' recursiveUpdate {} [
                  (evaluated.options or {})
                  {services.${serviceName} = evaluated.optionsService or {};}
                ];
                config =
                  if configIsRoot
                  then evaluated
                  else
                    mkMerge [
                      (evaluated.config or {})
                      (mkIf (cfg.enable) (evaluated.configEnable or {}))
                      {services.${serviceName} = evaluated.configService or {};}
                    ];
              }
            ]
            # Ideally services should have an `enable` option which declares whether the service is active or not.
            ++ (optional withEnable {
              options.services.${serviceName}.enable = mkEnableOption "the ${serviceName} network service on ${moduleArgs.name}";
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
