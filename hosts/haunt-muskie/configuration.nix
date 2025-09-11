{
  flake,
  config,
  ...
}: {
  imports = with flake.nixosModules; [
    shared

    disko-basic

    ../../users/leaf
  ];

  # services.headscale = {
  #   enable = true;
  #   port = 1001;
  #   settings = {
  #     server_url = "http://127.0.0.1:${config.network.services.headscale.port}";
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
