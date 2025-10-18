{
  config,
  hostName,
  lib,
  flake,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  inherit (flake.lib) mkServiceOptionsModule;
  inherit (config.lib.network) isServiceEnabledOnHost toFullDomain;

  serviceName = "headscale";
  cfg = config.network.services.${serviceName};
in {
  imports = [
    (mkServiceOptionsModule serviceName)
  ];
  config = mkMerge [
    (mkIf (isServiceEnabledOnHost serviceName) {
      services.headscale = {
        enable = true;
        address = "0.0.0.0";
        port = cfg.port;
        settings = {
          server_url = "https://" + (toFullDomain serviceName);
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
            base_domain = "dns." + (toFullDomain serviceName);
          };
        };
      };
    })
    # Enable tailscale for every host
    (mkIf config.network.enable {
      sops.secrets."tailscale/auth-key" = {sopsFile = ./secrets.yaml;};

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
            if (cfg.host == hostName)
            then "http://localhost:${toString cfg.port}"
            else "https://${toFullDomain serviceName}"
          }"
          "--hostname=${hostName}"
        ];
        # extraSetFlags = ["--accept-dns=false"];
      };

      # overwrite the autoconnect service
      systemd.services.tailscaled-autoconnect.script = let
        inherit (lib) escapeShellArgs;
        cfg = config.services.tailscale;
      in ''
        tailscale up --auth-key="$(cat ${cfg.authKeyFile})" ${escapeShellArgs cfg.extraUpFlags}
      '';
    })
  ];
}
