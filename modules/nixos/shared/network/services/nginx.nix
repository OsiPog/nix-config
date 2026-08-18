{
  flake,
  lib,
  config,
  hostName,
  ...
}: let
  inherit (builtins) filter listToAttrs typeOf any concatStringsSep;
  inherit (lib) mkIf pipe mkMerge concat;
  inherit (lib.attrsets) optionalAttrs nameValuePair;
  inherit (lib.strings) concatLines hasSuffix;

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
  virtualHostPorts = filter (p: p.proxy.method == "virtual-host") cfg.require.ports;
  # A stream port on our own host is served locally, no need to proxy it.
  streamPorts = filter (p: p.proxy.method == "stream" && (p.getAddress "<host>" != "localhost")) cfg.require.ports;
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
      provideEnable = {
        dns-overrides = listToAttrs (map (p: {
          name = p.proxy.domain;
          value = {
            query = p.proxy.domain;
            response =
              if cfg.ipAddress == null
              then config.vpn.ip
              else cfg.ipAddress;
          };
        }) (filter (p: p.proxy.domain != null) cfg.require.ports));

        # provide http and stream ports for forwarding to this proxy
        ports = pipe cfg.require.ports [
          (filter (p: p.proxy.method == "stream"))
          # http and https opened by nginx
          (concat [
            {
              port = 80;
              proxy.method = "stream";
            }
            {
              port = 443;
              proxy.method = "stream";
            }
          ])

          (map (p: nameValuePair (toString p.port) p))
          listToAttrs
        ];
      };
    }))
  ];
  config = mkIf (networkCfg.enable && cfg.enable) {
    assertions = [
      (let
        unknownDomains = pipe cfg.require.ports [
          (map (e: e.proxy.domain))
          (filter (domain: domain != null && ! any (confDomain: hasSuffix confDomain domain) ([hostCfg.domain] ++ hostCfg.extraDomains)))
        ];
      in {
        assertion = unknownDomains == [];
        message = "nginx: cannot proxy some ports, the following domains are not configured for ${hostName}: ${concatStringsSep ", " unknownDomains}";
      })
      {
        assertion = (filter (p: p.port == 80 || p.port == 443) streamPorts) == [] || virtualHostPorts == [];
        message = "nginx: when 80 or 443 are registered as stream ports virtual host ports cannot be used";
      }
    ];

    networking.firewall = {
      allowedTCPPorts = [80 443] ++ (map (p: p.port) (filter (p: !p.udp && (!p.proxy.hidden || cfg.ignoreHidden)) streamPorts));
      allowedUDPPorts = map (p: p.port) (filter (p: p.udp) streamPorts);
    };

    # If the current host is the service exposer expose the services to the domain
    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts = pipe virtualHostPorts [
        (map
          (p: let
            proxyConf = p.proxy;
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
                      proxyPass = p.getAddress "http://<host>:<port>";
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
      streamConfig = pipe streamPorts [
        (map (p: let
          proxyConf = p.proxy;
          extraStreamConfig =
            if (typeOf proxyConf.extraConfig == "string")
            then proxyConf.extraConfig
            else "";
        in ''
          server {
            proxy_pass ${p.getAddress "<host>:<port>"};
            proxy_timeout 1h;
            ${
            if p.udp
            then ''
              listen ${toString p.port} udp;
              proxy_protocol on;
              proxy_requests 8640000;
              proxy_responses 0;
            ''
            else ''
              listen ${toString p.port};
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
    security.acme.certs."${hostCfg.domain}".extraDomainNames = map (p: p.getAddress "<domain>") virtualHostPorts;
  };
}
