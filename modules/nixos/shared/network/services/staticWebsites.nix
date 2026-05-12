{
  config,
  lib,
  flake,
  hostName,
  ...
}: let
  inherit (builtins) listToAttrs;
  inherit (lib) mkOption mkIf mkDefault types;
  inherit (lib.lists) findFirstIndex;
  inherit (lib.strings) concatLines;
  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getServiceVariables;

  inherit
    (getServiceVariables "staticWebsites")
    serviceName
    portName
    networkCfg
    cfg
    ports
    stateDir
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({cfg, ...}: {
      optionsService = {
        sites = mkOption {
          description = "Static sites to be served";
          default = {};
          type = with types; listOf str;
        };
      };
      configEnable = {
        ports = listToAttrs (map (name: {
            name = portName + "-" + name;
            value = {
              port = 8050 + (findFirstIndex (x: x == name) (throw "wont happen") cfg.sites);
            };
          })
          cfg.sites);
      };
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) {
    services.nginx = {
      enable = true;
      appendHttpConfig = concatLines (map (name: ''
          server {
            listen ${toString ports.${portName + "-" + name}.port};
            server_name 0.0.0.0;
            location / {
              root ${stateDir}/${name};
            }
          }
        '')
        cfg.sites);
    };

    systemd.tmpfiles.rules =
      map (name: "d ${stateDir}/${name} 0750 ${config.services.nginx.user} ${config.services.nginx.group} -")
      cfg.sites;
  };
}
