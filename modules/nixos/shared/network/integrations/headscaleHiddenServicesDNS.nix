{
  lib,
  config,
  hostName,
  flake,
  ...
}: let
  inherit (builtins) filter;
  inherit (lib) mkIf pipe;
  inherit (lib.attrsets) genAttrs;

  inherit (flake.lib) uniqueBy;
  inherit (config.lib.network) allEnabledServicePorts toFullDomain;

  networkCfg = config.network;
  headscaleCfg = networkCfg.hosts.${hostName}.services.headscale;

  allRelevantServicePorts = filter (p: p.portCfg.reverseProxy.enable && p.portCfg.reverseProxy.subdomain != null) allEnabledServicePorts;
in
  mkIf (networkCfg.enable && headscaleCfg.enable) {
    services.headscale.settings.dns = {
      nameservers.split = pipe allRelevantServicePorts [
        (map (p: toFullDomain {inherit (p) serviceName portName hostName;}))
        (ss: genAttrs ss (_: []))
      ];

      extra_records = pipe allRelevantServicePorts [
        (map (p: {
          name = toFullDomain {inherit (p) serviceName portName hostName;};
          type = "A";
          value = networkCfg.hosts.${p.portCfg.reverseProxy.host}.vpn.ip;
        }))
        (uniqueBy "name")
      ];
    };
  }
