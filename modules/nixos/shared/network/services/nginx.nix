{
  flake,
  lib,
  config,
  ...
}: let
  inherit (builtins) filter listToAttrs typeOf attrValues;
  inherit (lib) mkIf pipe mkMerge;
  inherit (lib.attrsets) optionalAttrs attrsToList mapAttrs filterAttrs;
  inherit (lib.strings) concatLines;

  inherit (config.lib.network) getServiceVariables;
  inherit (flake.lib) mkNetworkHostServiceModule;

  inherit
    (getServiceVariables "nginx")
    serviceName
    networkCfg
    hostCfg
    cfg
    ;

  # TODO: source this from a proper tailscale-server interface again.
  vpnRange = "100.64.0.0/10";

  # Every port handed to us via `require.ports` is one we must reverse proxy.
  relevantPorts = attrsToList cfg.require.ports;

  relevantVirtualHostPorts = filter (e: e.value.proxy.method == "virtual-host") relevantPorts;
  # A stream port on our own host is served locally, no need to proxy it.
  relevantStreamPorts = filter (e: e.value.proxy.method == "stream" && (e.value.getAddress "<host>" != "localhost")) relevantPorts;
in {
  imports = [
    flake.nixosModules.porkbunAcme

    (mkNetworkHostServiceModule {inherit serviceName;} ({
      config,
      cfg,
      ...
    }: {
      optionsService = {
        ignoreHidden = lib.mkEnableOption "the hiding of hidding ports";
        ipAddress = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
      };
      provideEnable.dns-overrides =
        mapAttrs (_: p: {
          query = p.proxy.domain;
          response =
            if cfg.ipAddress == null
            then config.vpn.ip
            else cfg.ipAddress;
        })
        (filterAttrs (_: p: p.proxy.domain != null) cfg.require.ports);
    }))
  ];
  config = mkIf (networkCfg.enable && cfg.enable) {
    networking.firewall = {
      allowedTCPPorts = [443] ++ (map (p: p.value.port) (filter (p: !p.value.udp && (!p.value.proxy.hidden || cfg.ignoreHidden)) relevantStreamPorts));
      allowedUDPPorts = map (p: p.value.port) (filter (p: p.value.udp) relevantStreamPorts);
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
            proxyConf = p.value.proxy;
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
                      proxyPass = p.value.getAddress "http://<host>:<port>";
                      proxyWebsockets = true;
                    }
                    // (optionalAttrs (proxyConf.hidden && !cfg.ignoreHidden) {
                      extraConfig = ''
                        allow ${vpnRange};
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
          upstream = p.name;
          proxyConf = p.value.proxy;
          extraStreamConfig =
            if (typeOf proxyConf.extraConfig == "string")
            then proxyConf.extraConfig
            else "";
        in ''
          upstream ${upstream} {
            server ${p.value.getAddress "<host>:<port>"};
          }
          server {
            proxy_pass ${upstream};
            proxy_timeout 1h;
            ${
            if p.value.udp
            then ''
              listen ${toString p.value.port} udp;
              proxy_requests 8640000;
              proxy_responses 0;
              proxy_protocol on;
            ''
            else ''
              listen ${toString p.value.port};
            ''
          }
            ${
            if proxyConf.hidden && !cfg.ignoreHidden
            then ''
              allow ${vpnRange};
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
    security.acme.certs."${hostCfg.domain}".extraDomainNames = map (p: p.value.getAddress "<domain>") relevantVirtualHostPorts;
  };
}
