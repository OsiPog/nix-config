{
  config,
  hostName,
  lib,
  ...
}: let
  inherit (lib) mkIf;

  cfg = config.network.services.headscale;
in {
  options.network.services.headscale = config.lib.network.mkServiceOptions;
  config = mkIf (cfg.enable && cfg.host == hostName) {
    services.headscale = {
      enable = true;
      address = "0.0.0.0";
      port = cfg.port;
      settings = {
        server_url = "https://" + (config.lib.network.toFullDomain "headscale");
        dns = {
          override_local_dns = false;
          base_domain = "vpn." + (config.lib.network.toFullDomain "headscale");
          nameservers.global = [
            "1.1.1.1"
            "1.0.0.1"
            "2606:4700:4700::1111"
            "2606:4700:4700::1001"
          ];
        };
      };
    };
  };
}
