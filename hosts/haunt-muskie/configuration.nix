{flake, ...}: {
  imports = with flake.nixosModules; [
    shared

    disko-basic
    
    ../../users/leaf
  ];

  state.host.ssh = {
    public-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAcSqngrHbdtiCGzPmt6peImIQfYek/WLcaXIwrhN5oS root@haunt-muskie";
    allow-connections-from = ["biome-fest"];
  };

  networking.firewall.allowedTCPPorts = [
    1001
    80
    443
  ];

  services.httpd.enable = true;

  # services.headscale = {
  #   enable = true;
  #   port = 1001;
  #   settings = {
  #     server_url = "http://127.0.0.1:1002";
  #     dns = {
  #       base_domain = "kazuka.zip";
  #       nameservers.global = [
  #         "1.1.1.1"
  #         "1.0.0.1"
  #         "2606:4700:4700::1111"
  #         "2606:4700:4700::1001"
  #       ];
  #     };
  #     log.level = "debug";
    
  #   };
  # };

  system.stateVersion = "25.11";
}
