{
  config,
  lib,
  flake,
  hostName,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getServiceVariables;

  inherit
    (getServiceVariables "dnsmasq")
    serviceName
    networkCfg
    cfg
    ;

  stateDir = "/var/lib/dnsmasq"; # hardcoded in nixpkgs

  blocklistPath = stateDir + "/blocklist.txt";
  blocklistUrl = "https://big.oisd.nl/dnsmasq2"; # See https://oisd.nl/setup/dnsmasq
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({cfg, ...}: {
      provideEnable = {
        ports.dns = {
          port = 53;
          protocol = null;
          proxy.method = "stream";
        };
        dns-server.getAddress = cfg.provide.ports.dns.getAddress;
        backup-paths = [{path = stateDir;}];
      };
    }))
  ];
  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    {
      services.dnsmasq = {
        enable = true;
        resolveLocalQueries = false;
        settings = {
          no-resolv = true;
          server = ["1.1.1.1" "8.8.8.8"];
          conf-file = blocklistPath;
        };
      };

      systemd = {
        services.dnsmasq-update-blocklist = {
          after = ["dnsmasq.service"];
          path = [pkgs.wget];
          script = "wget '${blocklistUrl}' -O ${blocklistPath}";
          serviceConfig.Type = "oneshot";
        };
        timers.dnsmasq-update-blocklist = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "hourly";
            Unit = "dnsmasq-update-blocklist.service";
          };
        };
      };
    }
    # DNS OVERRIDES
    {
      services.dnsmasq.settings.address = map ({
        query,
        response,
      }: "/${query}/${response}")
      cfg.require.dns-overrides;
    }
  ]);
}
