{
  config,
  lib,
  flake,
  ...
}: let
  inherit (lib) mkIf mkOption;
  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getServiceVariables;

  inherit
    (getServiceVariables "nfs")
    serviceName
    networkCfg
    cfg
    ports
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      optionsService = let
        attrsOfPath = with lib.types; attrsOf (pathWith {absolute = true;});
      in {
        serve = mkOption {
          description = "Serve directories using NFS. Attrnames are identifiers.";
          type = attrsOfPath;
          default = {};
        };
        mount = mkOption {
          description = "Mount served directories using NFS. Attrnames are identifiers.";
          type = attrsOfPath;
          default = {};
        };
      };
    }))
  ];

  config =
    mkIf (networkCfg.enable && cfg.enable) {
    };
}
