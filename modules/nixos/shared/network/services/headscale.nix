{
  config,
  hostName,
  lib,
  flake,
  ...
}: let
  inherit (lib) mkIf;
  inherit (flake.lib) mkServiceOptionsModule;

  cfg = config.network.services.headscale;
in {
  imports = [
    (mkServiceOptionsModule "headscale")
  ];
  config = mkIf (cfg.enable && cfg.host == hostName) {
    services.headscale = {
      enable = true;
      address = "0.0.0.0";
      port = cfg.port;
      settings = {
        server_url = "https://" + (config.lib.network.toFullDomain "headscale");
        dns = {
          override_local_dns = false;
          nameservers.global = [
            "1.1.1.1"
            "1.0.0.1"
            "2606:4700:4700::1111"
            "2606:4700:4700::1001"
          ];
          # Magic DNS
          magic_dns = false;
          base_domain = "dns." + (config.lib.network.toFullDomain "headscale");
        };
      };
    };
  };
}
