{
  config,
  hostName,
  lib,
  flake,
  ...
}: let
  inherit (lib) mkIf mkMerge mkForce;
  inherit (flake.lib) mkServiceOptionsModule;
  inherit (config.lib.network) toFullDomain;

  serviceName = "headscale";
  networkCfg = config.network;
  cfg = networkCfg.hosts.${hostName}.services.${serviceName};
in {
  imports = [
    (mkServiceOptionsModule serviceName {
      config = {...}: {
        stateDir = "/var/lib/headscale"; # this is hardcoded in the nixos module
      };
    })

    ../../integrations/headscaleReverseProxyDNS.nix
  ];
  config = mkMerge [
    (mkIf (networkCfg.enable && cfg.enable) {
      services.headscale = {
        enable = true;
        address = "0.0.0.0";
        port = cfg.ports.http.port;
        settings = {
          server_url =
            "https://"
            + (toFullDomain {
              inherit serviceName;
              portName = "http";
            });
          dns = {
            override_local_dns = true;
            nameservers.global = [
              "1.1.1.1"
              "1.0.0.1"
              "2606:4700:4700::1111"
              "2606:4700:4700::1001"
            ];
            # Magic DNS
            magic_dns = true;
            base_domain =
              "dns."
              + (toFullDomain {
                inherit serviceName;
                portName = "http";
              });
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
          # Nginx uses tailscale to reverse proxy to other hosts on the tailnet. So the host that runs headscale must depend on nginx.
          # thus, we directly connect to localhost
          "--login-server=${
            if (cfg.enable)
            then "http://localhost:${toString cfg.ports.http.port}"
            else "https://${toFullDomain {
              inherit serviceName;
              portName = "http";
            }}"
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
