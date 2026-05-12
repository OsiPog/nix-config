{
  inputs,
  servicesById,
  ...
}: {
  domain = "axelhax.net";
  extraDomains = [inputs.nix-config-private.personal_domain];
  vpn.ip = "100.64.0.1";
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAcSqngrHbdtiCGzPmt6peImIQfYek/WLcaXIwrhN5oS root@haunt-muskie";
    allowConnectionsFrom = ["biome-fest" "dead-voxel"];
  };

  # --- RESTIC BACKUP
  # services.backup = {
  #   enable = true;
  #   host = "floating-trees";
  # };

  # --- NGINX REVERSE PROXY
  services.reverseProxy.enable = true;

  # --- MAIL
  services.mailserver = {
    id = "snm";
    enable = true;
    require = {
      inherit (servicesById.lldap.provide) ldap-server;
      mail-clients = builtins.foldl' (acc: e: acc ++ servicesById.${e}.provide.mail-clients) [] [
        "authelia"
      ];
    };
  };

  # --- HEADSCALE VPN
  services.headscale = {
    id = "headscale";
    enable = true;
    require.oidc-server = servicesById.authelia.provide.oidc-server;
  };
  ports.headscale.reverseProxy = {
    enable = true;
    domain = "vpn.axelhax.net";
  };
}
