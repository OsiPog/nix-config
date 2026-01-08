{
  config,
  lib,
  flake,
  hostName,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getVariables;

  inherit
    (getVariables "dnsmasq")
    serviceName
    networkCfg
    cfg
    ;

  stateDir = "/var/lib/dnsmasq"; # hardcoded in nixpkgs module definition

  blocklistPath = stateDir + "/blocklist.txt";
  blocklistUrl = "https://big.oisd.nl/dnsmasq2"; # See https://oisd.nl/setup/dnsmasq
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      configEnable.stateDirs = [stateDir];
    }))

    # ../integrations/hiddenServicesWithHeadscaleAndDnsmasq.nix
  ];
  config = mkIf (networkCfg.enable && cfg.enable) {
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
  };
}
