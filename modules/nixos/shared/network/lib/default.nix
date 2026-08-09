{
  config,
  lib,
  hostName,
  ...
}: let
  inherit (builtins) throw length filter head concatStringsSep foldl' replaceStrings attrNames attrValues listToAttrs;
  inherit (lib) pipe mkMerge;
  inherit (lib.attrsets) attrsToList filterAttrs mapAttrsToList mapAttrs mapAttrs';
  inherit (lib.lists) flatten;

  cfg = config.network;

  networkLib = rec {
    # Flatten all enabled services across all hosts into list of:
    # {
    #   hostName: string
    #   serviceName: string
    #   serviceCfg: attrset
    # }
    allEnabledServices = pipe cfg.hosts [
      attrsToList
      (map (host:
        pipe host.value.services [
          (filterAttrs (_: service: service.enable or true))
          (mapAttrsToList (name: value: {
            serviceName = name;
            serviceCfg = value;
            hostName = host.name;
          }))
        ]))
      flatten
    ];

    servicesById = pipe allEnabledServices [
      (map (service: {
        name = service.serviceCfg.id;
        value = service.serviceCfg;
      }))
      listToAttrs
    ];

    allServiceIds = attrNames servicesById;

    # Variables useful to network modules
    variables = rec {
      hostSrvs = variables.hostCfg.services;
      networkCfg = config.network;
      hostCfg = networkCfg.hosts.${hostName};
    };

    getServiceVariables = serviceName:
      variables
      // rec {
        inherit serviceName;
        cfg = variables.hostCfg.services.${serviceName};
        stateDir = "/var/lib/${serviceName}";
      };

    require = interfaceName: serviceIds: {
      ${interfaceName} = foldl' (acc: serviceId:
        acc
        // (mapAttrs' (name: value: {
            name = "${serviceId}-${name}";
            inherit value;
          })
          servicesById.${serviceId}.provide.${interfaceName}))
      {}
      serviceIds;
    };
  };
in {
  config = {
    lib.network = networkLib;
    network.sharedModules = [{lib = networkLib;}];
  };
}
