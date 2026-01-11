{...}: {
  domain = "axelhax.net";
  vpn.ip = "100.64.0.1";
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAcSqngrHbdtiCGzPmt6peImIQfYek/WLcaXIwrhN5oS root@haunt-muskie";
    allowConnectionsFrom = ["biome-fest" "dead-voxel"];
  };

  # --- RESTIC BACKUP
  services.backup = {
    enable = true;
    host = "floating-trees";
  };

  # --- NGINX REVERSE PROXY
  services.reverseProxy.enable = true;

  # --- MAIL
  services.mailserver = {
    enable = true;
    integrations.ldap.enable = true;
  };

  # --- HEADSCALE VPN
  services.headscale = {
    enable = true;
    integrations.oidc.enable = true;
  };
  ports.headscale.reverseProxy = {
    enable = true;
    domain = "vpn.axelhax.net";
  };
}
