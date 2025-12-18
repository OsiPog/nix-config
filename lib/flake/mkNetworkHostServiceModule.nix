flake: serviceName: module: {lib, ...}: let
  inherit (lib) mkEnableOption optionals;
in {
  network.sharedModules = [
    (moduleArgs: {
      imports = optionals (module != null) [
        (module (moduleArgs // {cfg = moduleArgs.config.services.${serviceName};}))
      ];
      options.services.${serviceName}.enable = mkEnableOption "the ${serviceName} network service on ${moduleArgs.name}";
    })
  ];
}
