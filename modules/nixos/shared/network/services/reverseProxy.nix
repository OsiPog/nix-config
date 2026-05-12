{
  flake,
  lib,
  config,
  ...
}: let
  inherit (builtins) filter listToAttrs typeOf;
  inherit (lib) mkIf pipe;
  inherit (lib.attrsets) recursiveUpdate;
  inherit (lib.strings) concatLines hasSuffix;

  inherit (config.lib.network) getAddress allPorts getServiceVariables;
  inherit (flake.lib) mkNetworkHostServiceModule;

  inherit
    (getServiceVariables "reverseProxy")
    serviceName
    networkCfg
    hostCfg
    cfg
    ;

  # Only the ports that should be reverse proxied by current host
  relevantPorts =
    filter (
      p:
        p.portCfg.reverseProxy.enable
        && hasSuffix hostCfg.domain p.portCfg.reverseProxy.domain
    )
    allPorts;

  relevantVirtualHostPorts = filter (e: e.portCfg.reverseProxy.method == "virtual-host") relevantPorts;
  relevantStreamPorts = filter (e: e.portCfg.reverseProxy.method == "stream") relevantPorts;
in {
  imports = [
    flake.nixosModules.porkbunAcme

    (mkNetworkHostServiceModule {
        inherit serviceName;
        enforceSingleInstance = true;
      }
      null)

    ../integrations/hiddenServicesWithHeadscaleAndDnsmasq.nix
  ];
  config = mkIf (networkCfg.enable && cfg.enable) {
    networking.firewall = {
      allowedTCPPorts = [443] ++ (map (p: p.port) (filter (p: !p.portCfg.reverseProxy.udp && !p.portCfg.reverseProxy.hidden) relevantStreamPorts));
      allowedUDPPorts = map (p: p.port) (filter (p: p.portCfg.reverseProxy.udp) relevantStreamPorts);
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
            proxyConf = p.portCfg.reverseProxy;
            virtualHostsConfig = {
              useACMEHost = hostCfg.domain;
              forceSSL = true;
              locations."/" = {
                proxyPass = p.portCfg.address "http://host:port";
                proxyWebsockets = true;
              };
            };
          in {
            name = proxyConf.domain;
            value = recursiveUpdate virtualHostsConfig proxyConf.extraConfig;
          }))
        listToAttrs
      ];
      streamConfig = pipe relevantStreamPorts [
        (map (p: let
          upstream = p.hostName + "-" + p.portName;
          proxyConf = p.portCfg.reverseProxy;
          extraStreamConfig =
            if (typeOf proxyConf.extraConfig == "string")
            then proxyConf.extraConfig
            else "";
        in ''
          upstream ${upstream} {
            server ${p.portCfg.address "localProtocol://host:port"};
          }
          server {
            proxy_pass ${upstream};
            proxy_timeout 1h;
            ${
            if proxyConf.udp
            then ''
              listen ${toString p.portCfg.port} udp;
              proxy_requests 8640000;
              proxy_responses 0;
              proxy_protocol on;
            ''
            else ''
              listen ${toString p.portCfg.port};
            ''
          }
            ${
            if p.portCfg.reverseProxy.hidden
            then ''
              allow 100.64.0.0/10;
              deny all;
            ''
            else ""
          }
            ${extraStreamConfig}
          }
        ''))
        concatLines
      ];
    };

    services.porkbunAcme.enable = true;
    users.users.nginx.extraGroups = ["acme"];
    security.acme.certs."${hostCfg.domain}".extraDomainNames = map (p: p.portCfg.address "domain") relevantVirtualHostPorts;
  };
}
