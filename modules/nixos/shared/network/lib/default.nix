{
  config,
  lib,
  hostName,
  ...
}: let
  inherit (builtins) throw length filter head concatStringsSep foldl';
  inherit (lib) pipe;
  inherit (lib.attrsets) attrsToList filterAttrs mapAttrsToList;
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

    getAddress = {
      portName,
      hostName ? null,
      asIP ? false,
      direct ? false,
      protocol ? null,
      appendPort ? true,
    }: let
      host =
        if hostName != null
        then hostName
        else
          pipe allPorts [
            (filter (e: e.portName == portName))
            (ports:
              if length ports == 0
              then throw "getAddress: port ${portName} cannot be found on any host."
              else if length ports >= 2
              then throw "getAddress: port ${portName} is defined on multiple hosts (${concatStringsSep ", " (map (e: e.hostName) ports)}). Please provide a hostName or enable the associated service on only one host."
              else (head ports).hostName)
          ];
      portCfg =
        if (cfg.hosts.${host} or null) == null
        then throw "getAddress: host ${host} is not defined"
        else if (cfg.hosts.${host}.ports.${portName} or null) == null
        then throw "getAddress: port ${portName} is not defined on host ${host}"
        else cfg.hosts.${host}.ports.${portName};
    in
      # optional protocol prefix
      (
        if protocol != null
        then "${protocol}://"
        else ""
      )
      + (
        # use IP if required
        if asIP
        then cfg.hosts.${host}.vpn.ip
        else
          (
            # Go with domain when port is reverse proxied
            if portCfg.reverseProxy.enable && !direct
            then portCfg.reverseProxy.domain
            else if cfg.hosts.${host}.domain != null && !direct
            then cfg.hosts.${host}.domain
            else
              (
                if host == config.networking.hostName
                then "localhost"
                else host
              )
          )
      )
      + (
        if appendPort
        then
          (
            if (portCfg.reverseProxy.enable && portCfg.reverseProxy.method == "virtual-host" && !direct && !asIP)
            then ""
            else ":" + (toString portCfg.port)
          )
        else ""
      );
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
      };

    getIntegrationVariables = integrationName: integratedServices:
      variables
      // rec {
        inherit integrationName integratedServices;
        integratedServiceEnable =
          foldl'
          (
            acc: elem:
              acc
              || (variables.hostSrvs.${elem}.enable
                && variables.hostSrvs.${elem}.integrations.${integrationName}.enable)
          )
          false
          integratedServices;
        serviceWithIntegrationEnable = serviceName:
          variables.hostSrvs.${serviceName}.enable
          && variables.hostSrvs.${serviceName}.integrations.${integrationName}.enable;
        serviceWithIntegrationEnabledAnywhere = serviceName:
          (
            filter (
              e:
                (e.serviceName == serviceName)
                && e.serviceCfg.integrations.${integrationName}.enable
            )
            allEnabledServices
          )
          != [];
      };
  };
in {
  config.lib.network = networkLib;
}
