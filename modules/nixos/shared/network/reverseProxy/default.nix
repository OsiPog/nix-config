{
  lib,
  config,
  hostName,
  ...
}: let
  inherit (builtins) filter listToAttrs concatLists;
  inherit (lib) mkIf pipe mapAttrsToList;
  inherit (lib.attrsets) attrsToList recursiveUpdate;
  inherit (lib.strings) concatLines;
  inherit (lib.lists) range flatten;
  inherit (config.lib.network) toFullDomain;

  cfg = config.network;
  hostCfg = cfg.hosts.${hostName};
  inherit (hostCfg.reverseProxy) domain;

  # Flatten services into a list of {serviceName, portName, port, reverseProxy, serviceHost}
  allServicePorts = pipe cfg.services [
    attrsToList
    (map (
      service:
        mapAttrsToList (portName: portCfg: {
          serviceName = service.name;
          portName = portName;
          portConfig = portCfg;
          serviceHost = service.value.host;
          serviceEnable = service.value.enable;
        })
        service.value.ports
    ))
    concatLists
  ];

  # Only the ports that should be reverse proxied by current host
  relevantPorts =
    filter (
      p:
        p.serviceEnable
        && p.portConfig.reverseProxy.enable
        && p.portConfig.reverseProxy.host == hostName
    )
    allServicePorts;

  relevantVirtualHostPorts = filter (e: e.portConfig.reverseProxy.method == "virtual-host") relevantPorts;
  relevantStreamPorts = pipe relevantPorts [
    (filter (e: e.portConfig.reverseProxy.method == "stream"))
    # Create a new entry for each port in range
    (p: let
      ports = range p.portConfig.portRange.from p.portConfig.portRange.to;
    in
      if (p.portConfig ? "portRange")
      then map (port: recursiveUpdate p {portConfig.port = port;}) ports
      else p)
    flatten
  ];

  ipAddrOf = serviceHost:
    if serviceHost == hostName
    then "127.0.0.1"
    # this will only work when both are in the same Tailscale network with magic dns
    else serviceHost;
in
  mkIf (cfg.enable && hostCfg.reverseProxy.enable) {
    networking = {
      inherit domain;
      firewall.allowedTCPPorts = [443] ++ (map (p: p.portConfig.port) relevantStreamPorts);
    };

    # If the current host is the service exposer expose the services to the domain
    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts = pipe relevantVirtualHostPorts [
        (map
          (portEntry: let
            proxyConf = portEntry.portConfig.reverseProxy;
            virtualHostsConfig = {
              useACMEHost = "default";
              forceSSL = true;
              locations."/" = {
                proxyPass = "http://${ipAddrOf portEntry.serviceHost}:${toString portEntry.portConfig.port}";
              };
            };
          in {
            name = toFullDomain portEntry.serviceName portEntry.portName;
            value = recursiveUpdate virtualHostsConfig proxyConf.extraVirtualHostsConfig;
          }))
        listToAttrs
      ];
      streamConfig = pipe relevantStreamPorts [
        (map (portEntry: ''
          server {
            listen ${toString portEntry.portConfig.port};
            proxy_pass ${ipAddrOf portEntry.serviceHost}:${toString portEntry.portConfig.port};
            proxy_timeout 20s;
          }
        ''))
        concatLines
      ];
    };

    users.users.nginx.extraGroups = ["acme"];

    sops.secrets."acme/porkbun" = {sopsFile = ./secrets.yaml;};

    security.acme = {
      acceptTerms = true;
      defaults.email = "osibluber@pm.me";
      certs.default = {
        inherit domain;
        extraDomainNames = map (p: toFullDomain p.serviceName p.portName) relevantVirtualHostPorts;
        dnsProvider = "porkbun";
        environmentFile = config.getSopsFile "acme/porkbun";
      };
    };
  }
