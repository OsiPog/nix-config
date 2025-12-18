{...}: {
  domain = "axelhax.net";
  vpn.ip = "100.64.0.1";
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAcSqngrHbdtiCGzPmt6peImIQfYek/WLcaXIwrhN5oS root@haunt-muskie";
    allowConnectionsFrom = ["biome-fest" "dead-voxel"];
  };
  ports = {
    headscale.reverseProxy = {
      enable = true;
      domain = "vpn.axelhax.net";
    };
  };
  services = {
    # backup = {
    #   enable = true;
    #   settings.host = "floating-trees";
    # };
    reverseProxy.enable = true;
    # vsftpd = {
    #   enable = true;
    #   ports = {
    #     control.port = 21;
    #     passive.portRange = {
    #       from = 40000;
    #       to = 40100;
    #     };
    #   };
    # };
    # mailserver.enable = true;
    headscale.enable = true;
  };
}
