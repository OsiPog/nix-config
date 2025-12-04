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
  inherit (config.lib.network) toFullDomain allEnabledServicePorts;
  inherit (flake.lib) mkServiceOptionsModule;

  serviceName = "reverseProxy";

  networkCfg = config.network;
  hostCfg = networkCfg.hosts.${hostName};
  cfg = hostCfg.services.${serviceName};

  # Only the ports that should be reverse proxied by current host
  relevantPorts =
    filter (
      p:
        p.portCfg.reverseProxy.enable
        && p.portCfg.reverseProxy.host == hostName
    )
    allEnabledServicePorts;

  relevantVirtualHostPorts = filter (e: e.portCfg.reverseProxy.method == "virtual-host") relevantPorts;
  relevantStreamPorts = filter (e: e.portCfg.reverseProxy.method == "stream") relevantPorts;

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
        allowedTCPPorts = [443] ++ (map (p: p.port) (filter (p: !p.portCfg.reverseProxy.udp) relevantStreamPorts));
        allowedUDPPorts = map (p: p.port) (filter (p: p.portCfg.reverseProxy.udp) relevantStreamPorts);
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
            proxyConf = p.portCfg.reverseProxy;
            virtualHostsConfig = {
              useACMEHost = "default";
              forceSSL = true;
              locations."/" = {
                proxyPass = "http://${ipAddrOf p.hostName}:${toString p.portCfg.port}";
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
            server ${ipAddrOf p.hostName}:${toString p.portCfg.port};
          }
          ${
            if p.portCfg.reverseProxy.udp
            then ''
              server {
                listen ${toString p.portCfg.port} udp;
                proxy_pass ${upstream};
                proxy_requests 8640000;
                proxy_timeout 20s;
                proxy_responses 0;
              }
            ''
            else ''
              server {
                listen ${toString p.portCfg.port};
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
