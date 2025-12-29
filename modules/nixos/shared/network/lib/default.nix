{
  config,
  lib,
  hostName,
  ...
}: let
  inherit (builtins) throw;
  inherit (lib) pipe;
  inherit (lib.attrsets) attrsToList filterAttrs mapAttrsToList;
  inherit (lib.lists) flatten range;

  cfg = config.network;

  networkLib = {
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
      hostName ? config.networking.hostName,
      asIP ? false,
      direct ? false,
      protocol ? null,
    }: let
      portCfg =
        if (cfg.hosts.${hostName} or null) == null
        then throw "getAddress: host ${hostName} is not defined"
        else if (cfg.hosts.${hostName}.ports.${portName} or null) == null
        then throw "getAddress: port ${portName} is not defined on host ${hostName}"
        else cfg.hosts.${hostName}.ports.${portName};
      portSuffix = ":" + (toString portCfg.port);
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
        then cfg.hosts.${hostName}.vpn.ip + portSuffix
        else
          (
            # Go with domain when port is reverse proxied
            if portCfg.reverseProxy.enable && !direct
            then portCfg.reverseProxy.domain
            else
              (
                if hostName == config.networking.hostName
                then "localhost"
                else hostName
              )
              + portSuffix
          )
      );

    getVariables = serviceName: rec {
      inherit serviceName;
      portName = serviceName;
      networkCfg = config.network;
      hostCfg = networkCfg.hosts.${hostName};
      cfg = hostCfg.services.${serviceName};
      ports = hostCfg.ports;
    };
  };
in {
  config.lib.network = networkLib;
}
