{
  config,
  lib,
  hostName,
  ...
}: let
  inherit (builtins) throw length filter head concatStringsSep foldl' replaceStrings attrNames attrValues listToAttrs;
  inherit (lib) pipe mkMerge;
  inherit (lib.attrsets) attrsToList filterAttrs mapAttrsToList mapAttrs mapAttrs';
  inherit (lib.lists) flatten range;

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

    # Flatten all declared ports across all hosts into a list of:
    # {
    #   hostName: string;
    #
    #   portName: string;
    #   port: int;
    #   portCfg: attrset;
    # }
    # Ports that declare ranges are flattened into individual entries.
    allPorts = pipe cfg.hosts [
      attrsToList
      (
        map (host:
          mapAttrsToList (portName: portCfg: let
            declaredPort = {
              hostName = host.name;

              inherit portName portCfg;
              inherit (portCfg) port;
            };
          in
            if portCfg.portRange == null
            then declaredPort
            else map (port: declaredPort // {inherit port;}) (range portCfg.portRange.from portCfg.portRange.to))
          host.value.ports)
      )
      flatten
    ];

    servicesById = pipe allEnabledServices [
      (map (service: {
        name = service.serviceCfg.id;
        value = service.serviceCfg;
      }))
      listToAttrs
    ];

    getAddress = {
      portName,
      hostName,
    }: let
      hostCfg = cfg.hosts.${hostName} or null;
      portCfg =
        if hostCfg == null
        then throw "getAddress: host ${hostName} is not defined"
        else if (hostCfg.ports.${portName} or null) == null
        then throw "getAddress: port ${portName} is not defined on host ${hostName}"
        else hostCfg.ports.${portName};

      address = rec {
        localProtocol =
          if portCfg.protocol != null
          then portCfg.protocol
          else throw "getAddress: ${hostName}: ${portName}: Protocol is null. It cannot be referenced.";
        proxyProtocol =
          if portCfg.reverseProxy.method == "virtual-host"
          then "https"
          else localProtocol;
        port = toString portCfg.port;
        domain =
          if portCfg.reverseProxy.enable
          then portCfg.reverseProxy.domain
          else if hostCfg.domain != null
          then hostCfg.domain
          else throw "getAddress: ${hostName}: ${portName}: Domain cannot be referenced because port is not reverse proxied.";
        host =
          if hostName == config.networking.hostName
          then "localhost"
          else hostName;
        ip = hostCfg.vpn.ip;
      };
    in
      replaceStrings (attrNames address) (attrValues address);

    serviceEnabledAnywhere = serviceName: (filter (e: e.serviceName == serviceName) allEnabledServices) != [];

    # Variables useful to network modules
    variables = rec {
      hostSrvs = variables.hostCfg.services;
      networkCfg = config.network;
      hostCfg = networkCfg.hosts.${hostName};
      ports = hostCfg.ports;
    };

    getServiceVariables = serviceName:
      variables
      // rec {
        inherit serviceName;
        portName = serviceName;
        cfg = variables.hostCfg.services.${serviceName};
        stateDir = "/var/lib/${serviceName}";
      };
  };
in {
  config.lib.network = networkLib;
}
