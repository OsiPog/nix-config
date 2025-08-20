{self, ...}: {
  imports = with self.nixosModules; [
    disko-basic
    
    ../../users/leaf
  ];

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
