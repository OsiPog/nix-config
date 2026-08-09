{
  lib,
  config,
  hostName,
  ...
}: let
  inherit (lib) mkIf mkMerge mkForce mkOption types;
  inherit (config.lib.network) servicesById;

  networkCfg = config.network;

  headscaleAddress = servicesById.headscale.provide.ports.http.getAddress;
in
  mkMerge [
    {
      network.sharedModules = [
        {
          options.vpn.ip = mkOption {
            type = types.str;
            description = "VPN IP address for the host";
          };
        }
      ];
    }

    (mkIf (networkCfg.enable) {
      # Enable tailscale for every host
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
            headscaleAddress (
              if headscaleAddress "<host>" == "localhost"
              then "http://<host>:<port>"
              else "https://<domain>"
            )
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
  ]
