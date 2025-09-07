{
  lib,
  config,
  hostName,
  ...
}: let
  inherit (builtins) filter;
  inherit (lib) mkIf pipe;
  inherit (lib.attrsets) attrsToList;
  inherit (builtins) listToAttrs;

  cfg = config.network;
  hostCfg = cfg.hosts.${hostName};
  inherit (hostCfg.reverseProxy) domain;

  # Only the services that should be reverse proxied by current host
  relevantServices = pipe cfg.services [
    attrsToList
    (filter (service: service.value.reverseProxy.enable && service.value.reverseProxy.host == hostName))
  ];
in
  mkIf hostCfg.reverseProxy.enable {
    networking = {
      inherit domain;
      firewall.allowedTCPPorts = [443];
    };

    # If the current host is the service exposer expose the services to the domain
    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts = pipe relevantServices [
        (map
          (service: let
            ipAddress =
              if service.value.host == hostName
              then "localhost"
              # TODO: this will only work when both are in the same Tailscale network with magic dns
              else service.value.host;
          in {
            name = config.lib.network.toFullDomain service.name;
            value = {
              useACMEHost = config.lib.network.toACMECert service.name;
              forceSSL = true;
              locations."/" = {
                proxyPass = "http://${ipAddress}:${toString service.value.port}";
              };
            };
          }))
        listToAttrs
      ];
    };

    users.users.nginx.extraGroups = ["acme"];

    sops.secrets."acme/porkbun" = {};

    security.acme = {
      acceptTerms = true;
      defaults.email = "osibluber@pm.me";
      certs = pipe relevantServices [
        (map
          (service: {
            name = config.lib.network.toACMECert service.name;
            value = {
              domain = config.lib.network.toFullDomain service.name;
              dnsProvider = "porkbun";
              environmentFile = config.getSopsFile "acme/porkbun";
            };
          }))
        listToAttrs
      ];
    };
  }
