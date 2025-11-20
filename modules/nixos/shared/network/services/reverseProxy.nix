{
  flake,
  lib,
  config,
  hostName,
  ...
}: let
  inherit (builtins) filter listToAttrs;
  inherit (lib) mkIf mkOption pipe types;
  inherit (lib.attrsets) recursiveUpdate mapAttrsToList filterAttrs attrsToList;
  inherit (lib.strings) concatLines;
  inherit (lib.lists) range flatten;
  inherit (config.lib.network) toFullDomain;
  inherit (flake.lib) mkServiceOptionsModule;

  serviceName = "reverseProxy";

  cfg = config.network;
  hostCfg = cfg.hosts.${hostName};
  serviceCfg = hostCfg.services.${serviceName};

  # Flatten all services in all hosts into a list of {port, host, serviceName, portName, portConfig}
  # portRange is also flattenend into individual entries
  allServicePorts = pipe cfg.hosts [
    attrsToList
    (map (
      {
        name,
        value,
      }: let
        hostName = name;
        services = value.services;
      in
        pipe services [
          # only include enabled services
          (filterAttrs (_: service: service.enable))
          (mapAttrsToList (serviceName: service:
            pipe service.ports [
              (mapAttrsToList (portName: portConfig: let
                servicePort = {
                  inherit portName portConfig serviceName hostName;
                };

                portRange =
                  if (portConfig.portRange != null)
                  then portConfig.portRange
                  else {
                    from = portConfig.port;
                    to = portConfig.port;
                  };
              in
                pipe portRange [
                  # to list of numbers
                  (r: range r.from r.to)
                  (map (port: {inherit port;} // servicePort))
                ]))
            ]))
        ]
    ))
    flatten
  ];

  # Only the ports that should be reverse proxied by current host
  relevantPorts =
    filter (
      p:
        p.portConfig.reverseProxy.enable
        && p.portConfig.reverseProxy.host == hostName
    )
    allServicePorts;

  relevantVirtualHostPorts = filter (e: e.portConfig.reverseProxy.method == "virtual-host") relevantPorts;
  relevantStreamPorts = filter (e: e.portConfig.reverseProxy.method == "stream") relevantPorts;

  ipAddrOf = serviceHost:
    if serviceHost == hostName
    then "127.0.0.1"
    # this will only work when both are in the same Tailscale network with magic dns
    else serviceHost;
in {
  imports = [
    flake.nixosModules.porkbunAcme
    (mkServiceOptionsModule serviceName {
      settingsOptions = {
        domain = mkOption {
          type = types.str;
          description = "The domain configured to connect to this host.";
          default = "";
        };
      };
    })
  ];
  config = mkIf (cfg.enable && serviceCfg.enable) {
    networking = {
      inherit (serviceCfg.settings) domain;
      firewall = {
        allowedTCPPorts = [443] ++ (map (p: p.port) (filter (p: !p.portConfig.reverseProxy.udp) relevantStreamPorts));
        allowedUDPPorts = map (p: p.port) (filter (p: p.portConfig.reverseProxy.udp) relevantStreamPorts);
      };
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
          (p: let
            proxyConf = p.portConfig.reverseProxy;
            virtualHostsConfig = {
              useACMEHost = "default";
              forceSSL = true;
              locations."/" = {
                proxyPass = "http://${ipAddrOf p.hostName}:${toString p.portConfig.port}";
                proxyWebsockets = true;
              };
            };
          in {
            name = toFullDomain {inherit (p) serviceName portName hostName;};
            value = recursiveUpdate virtualHostsConfig proxyConf.extraVirtualHostsConfig;
          }))
        listToAttrs
      ];
      streamConfig = pipe relevantStreamPorts [
        (map (p: let
          upstream = p.hostName + "-" + p.serviceName + "-" + p.portName;
        in ''
          upstream ${upstream} {
            server ${ipAddrOf p.hostName}:${toString p.portConfig.port};
          }
          ${
            if p.portConfig.reverseProxy.udp
            then ''
              server {
                listen ${toString p.portConfig.port} udp;
                proxy_pass ${upstream};
                proxy_requests 8640000;
                proxy_timeout 20s;
                proxy_responses 0;
              }
            ''
            else ''
              server {
                listen ${toString p.portConfig.port};
                proxy_pass ${upstream};
                proxy_timeout 20s;
              }
            ''
          }
        ''))
        concatLines
      ];
    };

    services.porkbunAcme.enable = true;
    security.acme.certs.default.extraDomainNames = map (p: toFullDomain {inherit (p) serviceName portName hostName;}) relevantVirtualHostPorts;
  };
}
