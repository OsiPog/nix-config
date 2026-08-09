{
  config,
  inputs,
  ...
}: let
  inherit (config.lib) require allServiceIds;
in {
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
    require = require "ports" allServiceIds;
  };
  # --- DNSMASQ, directly connect axelhax.net traffic through vpn
  services.dnsmasq = {
    id = "headscale-dns";
    enable = true;
    require = require "dns-overrides" ["proxy"];
  };
  # --- HEADSCALE VPN
  services.headscale = {
    id = "headscale";
    enable = true;
    provide.ports.http.proxy.domain = "vpn.axelhax.net";
    require =
      (require "oidc-servers" ["authelia"])
      // (require "dns-servers" ["headscale-dns"]);
  };

  # --- MAIL
  services.mailserver = {
    id = "snm";
    enable = true;
    provide.ports.smtp.proxy.domain = "axelhax.net";
    require =
      (require "ldap-servers" ["lldap"])
      // (require "mail-clients" ["authelia" "vikunja"]);
  };
}
