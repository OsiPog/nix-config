{
  config,
  hostName,
  lib,
  flake,
  ...
}: let
  inherit (lib) mkIf mkDefault mkMerge mkForce;
  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getAddress getServiceVariables;

  inherit
    (getServiceVariables "headscale")
    serviceName
    portName
    networkCfg
    cfg
    ports
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      configEnable = {
        ports.${portName}.port = mkDefault 8081;
      };
      configService.stateDir = "/var/lib/headscale"; # hardcoded in nixpkgs module
    }))

    ../../integrations/hiddenServicesWithHeadscaleAndDnsmasq.nix
  ];
  config = mkMerge [
    (mkIf (networkCfg.enable && cfg.enable) {
      services.headscale = {
        enable = true;
        address = "0.0.0.0";
        port = ports.${serviceName}.port;
        settings = {
          server_url = getAddress {
            protocol = "https";
            inherit portName;
          };
          dns = {
            override_local_dns = true;
            # can be overriden ;)
            nameservers.global = mkDefault [
              "1.1.1.1"
              "1.0.0.1"
              "2606:4700:4700::1111"
              "2606:4700:4700::1001"
            ];
            # Magic DNS
            magic_dns = true;
            base_domain = "dns." + (getAddress {inherit portName;});
          };
        };
      };
    })
    # Enable tailscale for every host
    (mkIf networkCfg.enable {
      sops.secrets."tailscale/auth-key" = {sopsFile = ./secrets.yaml;};

      # disable kresd
      services.kresd.enable = mkForce false;

      services.tailscale = {
        enable = true;
        openFirewall = true;
        interfaceName = "sculk";
        useRoutingFeatures = "both";
        authKeyFile = config.getSopsFile "tailscale/auth-key";
        extraUpFlags = [
          "--login-server=${
            getAddress {
              inherit portName;
              # Nginx uses tailscale to reverse proxy to other hosts on the tailnet. So the host that runs headscale must depend not on nginx.
              # thus, we directly connect to localhost
              direct = cfg.enable;
            }
          }"
          "--hostname=${hostName}"
        ];
        # extraSetFlags = ["--accept-dns=false"];
      };

      # overwrite the autoconnect service
      # systemd.services.tailscaled-autoconnect.script = let
      #   inherit (lib) escapeShellArgs;
      #   cfg = config.services.tailscale;
      # in
      #   mkForce ''
      #     tailscale up --auth-key="$(cat ${cfg.authKeyFile})" ${escapeShellArgs cfg.extraUpFlags}
      #   '';
    })
  ];
}
