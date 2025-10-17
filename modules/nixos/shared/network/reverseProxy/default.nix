{
  lib,
  config,
  hostName,
  ...
}: let
  inherit (builtins) filter listToAttrs;
  inherit (lib) mkIf pipe;
  inherit (lib.attrsets) attrsToList recursiveUpdate;
  inherit (lib.strings) concatLines;
  inherit (config.lib.network) toFullDomain;

  cfg = config.network;
  hostCfg = cfg.hosts.${hostName};
  inherit (hostCfg.reverseProxy) domain;

  # Only the services that should be reverse proxied by current host
  relevantServices = pipe cfg.services [
    attrsToList
    (filter (service: service.value.enable && service.value.reverseProxy.enable && service.value.reverseProxy.host == hostName))
  ];

  relevantVirtualHostServices = filter (e: e.value.reverseProxy.method == "virtual-host") relevantServices;
  relevantStreamServices = filter (e: e.value.reverseProxy.method == "stream") relevantServices;

  ipAddrOf = service:
    if service.value.host == hostName
    then "127.0.0.1"
    # this will only work when both are in the same Tailscale network with magic dns
    else service.value.host;
in
  mkIf (cfg.enable && hostCfg.reverseProxy.enable) {
    networking = {
      inherit domain;
      firewall.allowedTCPPorts = [443] ++ (map (e: e.value.port) relevantStreamServices);
    };

    # If the current host is the service exposer expose the services to the domain
    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts = pipe relevantVirtualHostServices [
        (map
          (service: let
            proxyConf = service.value.reverseProxy;
            virtualHostsConfig = {
              useACMEHost = "default";
              forceSSL = true;
              locations."/" = {
                proxyPass = "http://${ipAddrOf service}:${toString service.value.port}";
              };
            };
          in {
            name = toFullDomain service.name;
            value = recursiveUpdate virtualHostsConfig proxyConf.extraVirtualHostsConfig;
          }))
        listToAttrs
      ];
      streamConfig = pipe relevantStreamServices [
        (map (service: ''
          server {
            listen ${toString service.value.port};
            proxy_pass ${ipAddrOf service}:${toString service.value.port};
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
        extraDomainNames = map (service: toFullDomain service.name) relevantVirtualHostServices;
        dnsProvider = "porkbun";
        environmentFile = config.getSopsFile "acme/porkbun";
      };
    };
  }
