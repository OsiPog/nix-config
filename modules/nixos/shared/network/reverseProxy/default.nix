{
  lib,
  config,
  hostName,
  ...
}: let
  inherit (builtins) filter listToAttrs;
  inherit (lib) mkIf pipe;
  inherit (lib.attrsets) recursiveUpdate mapAttrsToList filterAttrs attrsToList;
  inherit (lib.strings) concatLines;
  inherit (lib.lists) range flatten;
  inherit (config.lib.network) toFullDomain;

  cfg = config.network;
  hostCfg = cfg.hosts.${hostName};
  inherit (hostCfg.reverseProxy) domain;

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
        (map (p: ''
          server {
            listen ${toString p.portConfig.port};
            proxy_pass ${ipAddrOf p.hostName}:${toString p.portConfig.port};
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
        extraDomainNames = map (p: toFullDomain {inherit (p) serviceName portName hostName;}) relevantVirtualHostPorts;
        dnsProvider = "porkbun";
        environmentFile = config.getSopsFile "acme/porkbun";
      };
    };
  }
