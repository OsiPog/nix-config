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
  inherit (lib.lists) unique findFirst;

  inherit (config.lib.network) allEnabledServicePorts allEnabledServices toFullDomain;

  uniqueBy = attr: listOfAttrs: let
    uniqueValues = unique (map (e: e.${attr}) listOfAttrs);
  in
    map (value: findFirst (e: e.${attr} == value) (throw "Will always find it") listOfAttrs) uniqueValues;

  networkCfg = config.network;
  headscaleCfg = networkCfg.hosts.${hostName}.services.headscale;
in
  mkIf (networkCfg.enable && headscaleCfg.enable) {
    services.headscale.settings.dns = {
      nameservers.split = pipe allEnabledServices [
        (filter (s: s.serviceCfg.enable && s.serviceName == "reverseProxy"))
        (map (s: s.serviceCfg.settings.domain))
        (ss: genAttrs ss (_: []))
      ];

      extra_records = pipe allEnabledServicePorts [
        (filter (p: p.portCfg.reverseProxy.enable))
        (map (p: {
          name = toFullDomain {inherit (p) serviceName portName hostName;};
          type = "A";
          value = networkCfg.hosts.${p.portCfg.reverseProxy.host}.vpn.ip;
        }))
        (uniqueBy "name")
      ];
    };
  }
