{
  config,
  lib,
  ...
}: let
  inherit (builtins) attrNames filter length head throw getAttr;
  inherit (lib) pipe;
  inherit (lib.lists) flatten;

  cfg = config.network;
in {
  config.lib.network = {
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
}
