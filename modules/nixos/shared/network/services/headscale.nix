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
        prefixes.v4 = "10.0.0.0/24";
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
  };
}
