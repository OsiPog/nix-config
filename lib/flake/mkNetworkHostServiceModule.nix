flake: {
  serviceName,
  withEnable ? true,
}: module: {lib, ...}: let
  inherit (builtins) foldl' elem attrNames filter;
  inherit (lib) mkEnableOption mkMerge mkIf;
  inherit (lib.lists) optional;
  inherit (lib.attrsets) recursiveUpdate;
in {
  network.sharedModules = [
    (moduleArgs: let
      cfg = moduleArgs.config.services.${serviceName};
      evaluated =
        if module != null
        then module (moduleArgs // {inherit cfg;})
        else {};

      metaAttrNames = [
        "imports"
        "options"
        "config"
        "optionsService"
        "configEnable"
      ];

      configIsRoot = filter (name: ! (elem name metaAttrNames)) (attrNames evaluated) == [];
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
                ];
          }
        ]
        ++ (optional withEnable {
          options.services.${serviceName}.enable = mkEnableOption "the ${serviceName} network service on ${moduleArgs.name}";
        });
    })
  ];
}
