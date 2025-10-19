{
  lib,
  config,
  hostName,
  ...
}: let
  cfg = config.network;
in {
  config.lib.network = {
    toFullDomain = serviceName: portName: let
      portCfg = cfg.services.${serviceName}.ports.${portName};
    in "${portCfg.reverseProxy.subdomain}.${cfg.hosts.${portCfg.reverseProxy.host}.reverseProxy.domain}";

    isServiceEnabledOnHost = serviceName: cfg.enable && cfg.services.${serviceName}.enable && cfg.services.${serviceName}.host == hostName;
  };
}
