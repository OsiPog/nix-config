{
  config,
  hostName,
  lib,
  flake,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  inherit (flake.lib) mkServiceOptionsModule;

  cfg = config.network.services.headscale;
in {
  imports = [
    (mkServiceOptionsModule "headscale")
  ];
  config = mkMerge [
    (mkIf (cfg.enable && cfg.host == hostName) {
      services.headscale = {
        enable = true;
        address = "0.0.0.0";
        port = cfg.port;
        settings = {
          server_url = "https://" + (config.lib.network.toFullDomain "headscale");
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
            base_domain = "dns." + (config.lib.network.toFullDomain "headscale");
          };
        };
      };
    })
    # Enable tailscale for every host
    {
      sops.secrets."tailscale/auth-key" = {sopsFile = ./secrets.yaml;};

      services.tailscale = {
        enable = true;
        openFirewall = true;
        interfaceName = "sculk";
        useRoutingFeatures = "both";
        authKeyFile = config.getSopsFile "tailscale/auth-key";
        extraUpFlags = [
          "--login-server=https://${config.lib.network.toFullDomain "headscale"}"
          "--hostname=${hostName}"
        ];
        # extraSetFlags = ["--accept-dns=false"];
      };
    }
  ];
}
