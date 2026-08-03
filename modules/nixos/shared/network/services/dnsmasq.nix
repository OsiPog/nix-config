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
    portName
    ports
    ;

  stateDir = "/var/lib/dnsmasq"; # hardcoded in nixpkgs

  blocklistPath = stateDir + "/blocklist.txt";
  blocklistUrl = "https://big.oisd.nl/dnsmasq2"; # See https://oisd.nl/setup/dnsmasq
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({config, ...}: {
      configEnable.ports.${portName} = {
        port = 53;
        protocol = null;
        reverseProxy.method = "stream";
      };
      provideEnable = {
        dns-server.getAddress = config.ports.${portName}.getAddress;
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
