{
  inputs,
  servicesById,
  nixosConfig,
  ...
}: {
  domain = "axelhax.net";
  extraDomains = [inputs.nix-config-private.personal_domain];
  vpn.ip = "100.64.0.1";
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAcSqngrHbdtiCGzPmt6peImIQfYek/WLcaXIwrhN5oS root@haunt-muskie";
    allowConnectionsFrom = ["biome-fest" "dead-voxel" "floating-trees"];
  };

  # --- RESTIC BACKUP
  # services.backup = {
  #   enable = true;
  #   host = "floating-trees";
  # };

  # --- NGINX REVERSE PROXY
  services.nginx = {
    id = "proxy";
    enable = true;
    # proxy every reverse-proxied port declared anywhere in the network
    require.ports = nixosConfig.lib.network.proxiedPorts;
  };
  # --- DNSMASQ, directly connect axelhax.net traffic through vpn
  services.dnsmasq = {
    id = "headscale-dns";
    enable = true;
    require.dns-overrides = servicesById.proxy.provide.dns-overrides;
  };
  # --- HEADSCALE VPN
  services.headscale = {
    id = "headscale";
    enable = true;
    require.oidc-server = servicesById.authelia.provide.oidc-server;
    require.dns-server = servicesById.headscale-dns.provide.dns-server;
  };
  services.headscale.provide.ports.headscale.proxy.domain = "vpn.axelhax.net";

  # --- MAIL
  services.mailserver = {
    id = "snm";
    enable = true;
    require = {
      inherit (servicesById.lldap.provide) ldap-server;
      mail-clients = builtins.foldl' (acc: e: acc ++ servicesById.${e}.provide.mail-clients) [] [
        "authelia"
        "vikunja"
      ];
    };
  };
  services.mailserver.provide.ports.submissions.proxy.domain = "axelhax.net";
}
