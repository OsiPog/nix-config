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

    # Every reverse-proxied port across all enabled services, ready to be handed
    # to the nginx service via `require.ports`. Keyed uniquely by "<id>-<portName>".
    # A port counts as proxied when it declares a `proxy.domain`.
    proxiedPorts = pipe allEnabledServices [
      (map (service:
        mapAttrsToList (portName: portCfg: {
          name = "${service.serviceCfg.id}-${portName}";
          value = {inherit (portCfg) port udp proxy getAddress;};
        })
        service.serviceCfg.provide.ports))
      flatten
      (filter (e: e.value.proxy.domain != null))
      listToAttrs
    ];

    servicesById = pipe allEnabledServices [
      (map (service: {
        name = service.serviceCfg.id;
        value = service.serviceCfg;
      }))
      listToAttrs
    ];

    serviceEnabledAnywhere = serviceName: (filter (e: e.serviceName == serviceName) allEnabledServices) != [];

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
  };
in {
  config.lib.network = networkLib;
}
