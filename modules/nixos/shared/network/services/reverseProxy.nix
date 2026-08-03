{
  flake,
  lib,
  config,
  hostName,
  ...
}: let
  inherit (builtins) filter listToAttrs typeOf;
  inherit (lib) mkIf pipe mkMerge;
  inherit (lib.attrsets) recursiveUpdate optionalAttrs;
  inherit (lib.strings) concatLines hasSuffix;

  inherit (config.lib.network) allPorts getServiceVariables;
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
  relevantStreamPorts = filter (e: e.portCfg.reverseProxy.method == "stream" && (e.portCfg.getAddress "<host>" != "localhost")) relevantPorts;

  tailscaleServer = cfg.require.tailscale-server;
in {
  imports = [
    flake.nixosModules.porkbunAcme

    (mkNetworkHostServiceModule {inherit serviceName;} ({
      config,
      cfg,
      ...
    }: let
      relevantPorts = filter (p: p.portCfg.reverseProxy.enable && (hasSuffix config.domain p.portCfg.reverseProxy.domain)) allPorts;
    in {
      optionsService = {
        ignoreHidden = lib.mkEnableOption "the hiding of hidding ports";
        ipAddress = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
      };
      provideEnable.dns-overrides =
        map (p: {
          query = p.portCfg.reverseProxy.domain;
          response =
            if cfg.ipAddress == null
            then config.vpn.ip
            else cfg.ipAddress;
        })
        relevantPorts;
    }))
  ];
  config = mkIf (networkCfg.enable && cfg.enable) {
    networking.firewall = {
      allowedTCPPorts = [443] ++ (map (p: p.port) (filter (p: !p.portCfg.udp && (!p.portCfg.reverseProxy.hidden || cfg.ignoreHidden)) relevantStreamPorts));
      allowedUDPPorts = map (p: p.port) (filter (p: p.portCfg.udp) relevantStreamPorts);
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
          in {
            name = proxyConf.domain;
            value = mkMerge [
              # merge with extra config given from port
              proxyConf.extraConfig
              {
                useACMEHost = hostCfg.domain;
                forceSSL = true;
                locations = let
                  common =
                    {
                      proxyPass = p.portCfg.getAddress "http://<host>:<port>";
                      proxyWebsockets = true;
                    }
                    // (optionalAttrs (proxyConf.hidden && !cfg.ignoreHidden) {
                      extraConfig = ''
                        allow ${tailscaleServer.ip4Space};
                        deny all;
                      '';
                    });
                in {
                  "/" = common;
                  ".well-known/" = mkMerge [
                    common
                    {
                      extraConfig = ''
                        add_header Access-Control-Allow-Origin "*";
                        add_header Access-Control-Allow-Methods "*";
                      '';
                    }
                  ];
                };
              }
            ];
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
            server ${p.portCfg.getAddress "<host>:<port>"};
          }
          server {
            proxy_pass ${upstream};
            proxy_timeout 1h;
            ${
            if p.portCfg.udp
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
            if p.portCfg.reverseProxy.hidden && !cfg.ignoreHidden
            then ''
              allow ${tailscaleServer.ip4Space};
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
    security.acme.certs."${hostCfg.domain}".extraDomainNames = map (p: p.portCfg.getAddress "<domain>") relevantVirtualHostPorts;
  };
}
