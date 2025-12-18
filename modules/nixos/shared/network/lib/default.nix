{
  config,
  lib,
  ...
}: let
  inherit (builtins) attrNames filter length head throw getAttr;
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
    # allEnabledServices = pipe cfg.hosts [
    #   attrsToList
    #   (map (host:
    #     pipe host.value.services [
    #       (filterAttrs (_: service: service.enable))
    #       (mapAttrsToList (name: value: {
    #         serviceName = name;
    #         serviceCfg = value;
    #         hostName = host.name;
    #       }))
    #     ]))
    #   flatten
    # ];

    # Flatten all enabled services across all hosts into a list of:
    # {
    #   hostName: string;
    #
    #   serviceName: string;
    #   serviceCfg string;
    #
    #   port: int;
    #   portName: string;
    #   portCfg: attrset;
    # }
    # For port configs that define ranges create a servicePort for each port in that range
    # allEnabledServicePorts = pipe allEnabledServices [
    #   (map (s:
    #     pipe s.serviceCfg.ports [
    #       (mapAttrsToList (portName: portCfg:
    #         # Create a servicePort for each port in a port range
    #           pipe portCfg.portRange [
    #             # For ports that do not have a range but a single one simulate a range of one
    #             (
    #               portRange:
    #                 if (portRange == null)
    #                 then {
    #                   from = portCfg.port;
    #                   to = portCfg.port;
    #                 }
    #                 else portRange
    #             )
    #             # create list for all ports in the port range
    #             (r: range r.from r.to)
    #             # define the servicePort for each port in the range
    #             (map (port: {
    #               inherit (s) serviceCfg serviceName hostName;
    #               inherit port portName portCfg;
    #             }))
    #           ]))
    #     ]))
    #   flatten
    # ];

    getAddress = {
      portName,
      hostName ? config.networking.hostName,
      asIP ? false,
      direct ? false,
      protocol ? null,
    }: let
      portCfg =
        if !(cfg.hosts ? hostName)
        then throw "getAddress: host ${hostName} is not defined"
        else if !(cfg.hosts.${hostName}.ports ? portName)
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
  };
in {
  config.lib.network = networkLib;
}
