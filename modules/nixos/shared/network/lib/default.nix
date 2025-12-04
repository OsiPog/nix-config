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
    #   service: attrset
    # }
    allEnabledServices = pipe cfg.hosts [
      attrsToList
      (map (host:
        pipe host.value.services [
          (filterAttrs (_: service: service.enable))
          (mapAttrsToList (name: value: {
            serviceName = name;
            service = value;
            hostName = host.name;
          }))
        ]))
      flatten
    ];

    # Flatten all enabled services across all hosts into a list of:
    # {
    #   hostName: string;
    #
    #   serviceName: string;
    #
    #   port: int;
    #   portName: string;
    #   portConfig: attrset;
    # }
    # For port configs that define ranges create a servicePort for each port in that range
    allEnabledServicePorts = pipe allEnabledServices [
      (map (s:
        pipe s.service.ports [
          (mapAttrsToList (portName: portConfig:
            # Create a servicePort for each port in a port range
              pipe portConfig.portRange [
                # For ports that do not have a range but a single one simulate a range of one
                (
                  portRange:
                    if (portRange == null)
                    then {
                      from = portConfig.port;
                      to = portConfig.port;
                    }
                    else portRange
                )
                # create list for all ports in the port range
                (r: range r.from r.to)
                # define the servicePort for each port in the range
                (map (port: {
                  inherit (s) serviceName hostName;
                  inherit port portName portConfig;
                }))
              ]))
        ]))
      flatten
    ];
    toFullDomain = {
      serviceName,
      portName ? null,
      hostName ? null,
    }: let
      # Determine which host to use
      selectedHostName =
        if hostName != null
        then hostName
        else let
          # Find hosts where this service is enabled
          enabledHosts = pipe cfg.hosts [
            attrNames
            (filter (hostName: cfg.hosts.${hostName}.services.${serviceName}.enable or false))
          ];
          numHosts = length enabledHosts;
        in
          if numHosts == 0
          then throw "Service '${serviceName}' is not enabled on any host"
          else if numHosts > 1
          then throw "Service '${serviceName}' is enabled on multiple hosts (${toString enabledHosts}). Please specify hostName explicitly."
          else head enabledHosts;

      serviceCfg = cfg.hosts.${selectedHostName}.services.${serviceName};

      # Determine which port to use
      selectedPortName =
        if portName != null
        then portName
        else let
          # Find ports with method "virtual-host"
          virtualHostPorts = pipe serviceCfg.ports [
            attrNames
            (filter (p: serviceCfg.ports.${p}.reverseProxy.enable && serviceCfg.ports.${p}.reverseProxy.method == "virtual-host"))
          ];
          numPorts = length virtualHostPorts;
        in
          if numPorts == 0
          then throw "Service '${serviceName}' on host '${selectedHostName}' has no ports with method 'virtual-host'"
          else if numPorts > 1
          then throw "Service '${serviceName}' on host '${selectedHostName}' has multiple ports with method 'virtual-host' (${toString virtualHostPorts}). Please specify portName explicitly."
          else head virtualHostPorts;

      portCfg = serviceCfg.ports.${selectedPortName};
    in "${portCfg.reverseProxy.subdomain}.${cfg.hosts.${portCfg.reverseProxy.host}.services.reverseProxy.settings.domain}";
  };
in {
  config.lib.network = networkLib;
}
