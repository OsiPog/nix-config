{
  lib,
  config,
  hostName,
  ...
}: let
  inherit (builtins) filter length listToAttrs;
  inherit (lib) mkIf pipe mkMerge;
  inherit (lib.lists) unique;

  inherit (config.lib.network) allEnabledServices allEnabledServicePorts toFullDomain;

  networkCfg = config.network;
  headscaleCfg = networkCfg.hosts.${hostName}.services.headscale;
  reverseProxyCfg = networkCfg.hosts.${hostName}.services.reverseProxy;
  dnsmasqCfg = networkCfg.hosts.${hostName}.services.dnsmasq;

  nameservers = pipe allEnabledServices [
    (filter (s: s.serviceName == "dnsmasq"))
    (map (s: networkCfg.hosts.${s.hostName}.vpn.ip))
  ];
in
  mkMerge [
    # --- HEADSCALE
    # Set the dns nameservers as the global nameservers headscale uses
    (mkIf (networkCfg.enable && headscaleCfg.enable && (length nameservers > 0)) {
      services.headscale.settings.dns.nameservers.global = nameservers;
    })
    # --- REVERSE PROXY
    # only allow the tailnet on hidden services
    (mkIf (networkCfg.enable && reverseProxyCfg.enable) (let
      allowRule = ''
        allow 100.64.0.0/10;
        deny all;
      '';
    in {
      services.nginx.virtualHosts = pipe allEnabledServicePorts [
        (filter (p: p.portCfg.reverseProxy.enable && p.portCfg.reverseProxy.hidden && p.portCfg.reverseProxy.method == "virtual-host"))
        (map (p: {
          name = toFullDomain {inherit (p) serviceName portName hostName;};
          value.extraConfig = allowRule;
        }))
        listToAttrs
        # TODO: Due to limitation how the stream nginx config was implemented, stream denial is implemented in ../services/reverseProxy.nix
      ];
    }))

    # --- DNSMASQ
    # add extra entries that DNS directly through the tailnet so that nginx can allow the requests
    (mkIf (networkCfg.enable && dnsmasqCfg.enable) {
      services.dnsmasq.settings.address = pipe allEnabledServicePorts [
        (filter (p: p.portCfg.reverseProxy.enable))
        (map (
          p: "/${toFullDomain {inherit (p) serviceName portName hostName;}}/${networkCfg.hosts.${p.portCfg.reverseProxy.host}.vpn.ip}"
        ))
        unique
      ];
    })
  ]
