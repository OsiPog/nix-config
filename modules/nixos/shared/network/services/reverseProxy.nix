{
  flake,
  lib,
  config,
  hostName,
  pkgs,
  ...
}: let
  inherit (builtins) filter listToAttrs typeOf;
  inherit (lib) mkIf mkOption pipe types;
  inherit (lib.attrsets) recursiveUpdate mapAttrsToList filterAttrs attrsToList;
  inherit (lib.strings) concatLines;
  inherit (lib.lists) range flatten;

  inherit (config.lib.network) toFullDomain allEnabledServicePorts;
  inherit (flake.lib) mkNetworkHostServiceModule;

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

    (mkNetworkHostServiceModule serviceName null)

    # ../integrations/hiddenServicesWithHeadscaleAndDnsmasq.nix
  ];
  config = mkIf (networkCfg.enable && cfg.enable) {
    networking = {
      inherit (cfg.settings) domain;
      firewall = {
        allowedTCPPorts = [443] ++ (map (p: p.port) (filter (p: !p.portCfg.reverseProxy.udp && !p.portCfg.reverseProxy.hidden) relevantStreamPorts));
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
              useACMEHost = cfg.settings.domain;
              forceSSL = true;
              locations."/" = {
                proxyPass = "http://${ipAddrOf p.hostName}:${toString p.portCfg.port}";
                proxyWebsockets = true;
              };
            };
          in {
            name = toFullDomain {inherit (p) serviceName portName hostName;};
            value = recursiveUpdate virtualHostsConfig proxyConf.extraConfig;
          }))
        listToAttrs
      ];
      streamConfig = pipe relevantStreamPorts [
        (map (p: let
          upstream = p.hostName + "-" + p.serviceName + "-" + p.portName;
          proxyConf = p.portCfg.reverseProxy;
          extraStreamConfig =
            if (typeOf proxyConf.extraConfig == "string")
            then proxyConf.extraConfig
            else "";
        in ''
          upstream ${upstream} {
            server ${ipAddrOf p.hostName}:${toString p.portCfg.port};
          }
          server {
            proxy_pass ${upstream};
            ${
            if proxyConf.udp
            then ''
              listen ${toString p.portCfg.port} udp;
              proxy_requests 8640000;
              proxy_responses 0;
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
    security.acme.certs."${cfg.settings.domain}".extraDomainNames = map (p: toFullDomain {inherit (p) serviceName portName hostName;}) relevantVirtualHostPorts;
  };
}
