flake: {
  integrationName,
  integratedServices,
  serviceName,
  portName,
  protocol ? null,
}: networkModule: {
  lib,
  config,
  ...
}: let
  inherit (lib) mkOption mkEnableOption mkDefault mkIf;
  inherit (lib.lists) findFirst;

  inherit (flake.lib) mkModuleWithExtraMetaAttrs;

  inherit (config.lib.network) allPorts getAddress;
  inherit (config.lib.network.variables) hostCfg;
in {
  network.sharedModules =
    map
    (integratedServiceName: moduleArgs: let
      cfg = hostCfg.services.${integratedServiceName}.integrations.${integrationName};
    in {
      imports = [
        (mkModuleWithExtraMetaAttrs {
            extraSpecialArgs = {
              inherit cfg;
              integrationServiceCfg = config.network.hosts.${cfg.host}.services.${serviceName};
            };
            mapExtraMetaAttr = name: content:
              if name == "optionsIntegration"
              then {options.services.${integratedServiceName}.integrations.${integrationName} = content;}
              else if name == "configIntegrationEnable"
              then {config.services.${integratedServiceName}.integrations.${integrationName} = mkIf cfg.enable content;}
              else null;
          }
          networkModule)

        {
          options.services.${integratedServiceName}.integrations.${integrationName} = mkOption {
            description = "${serviceName} integration";
            type = lib.types.submodule (integrationModule: let
              defaultHost = (findFirst (p: p.portName == portName) (throw "${integrationName} Integration: ${portName} port is not defined on any host.") allPorts).hostName;

              address = getAddress {
                inherit portName protocol;
                hostName = integrationModule.config.host;
              };
            in {
              options = {
                enable = mkEnableOption "${serviceName} integration";
                host = mkOption {
                  description = "The host the ${serviceName} service is running on.";
                  type = lib.types.str;
                };
                address = mkOption {
                  description = "Read only option of the ${serviceName} address";
                  readOnly = true;
                  default = address;
                };
              };
              config = mkIf integrationModule.config.enable {
                host = mkDefault defaultHost;
              };
            });
            default = {};
          };
        }
      ];
    })
    integratedServices;
}
