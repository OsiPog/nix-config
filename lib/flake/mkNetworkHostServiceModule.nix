flake: {
  serviceName,
  withEnable ? true,
}: module: {lib, ...}: let
  inherit (lib) mkEnableOption optional;
in {
  network.sharedModules = [
    (moduleArgs: {
      imports =
        []
        ++ (optional (module != null) (
          module (moduleArgs // {cfg = moduleArgs.config.services.${serviceName};})
        ))
        ++ (optional withEnable {
          options.services.${serviceName}.enable = mkEnableOption "the ${serviceName} network service on ${moduleArgs.name}";
        });
    })
  ];
}
