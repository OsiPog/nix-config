# This is a special nix module. It is imported into `networking.hosts.<name>` of every nixos configuration.
# So that each host can see the network configuration of all other hosts.
{servicesById, ...}: {
  vpn.ip = "100.64.0.4";
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDYdr33vJvtTnrSDiEhCUkc0fL7GyrZG9UEL8zjaKJpU root@floating-trees";
    allowConnectionsFrom = ["dead-voxel" "biome-fest"];
  };

  ports.vmu = {
    port = 8080;
    reverseProxy.domain = "vmu.axelhax.net";
  };

  # --- DNSMASQ
  services.dnsmasq.enable = true;

  # --- RESTIC
  # services.backup = {
  #   enable = true;
  #   server = {
  #     enable = true;
  #     repository = "/mnt/blaze";
  #   };
  # };

  # --- MINECRAFT
  # services.minecraft-server.enable = true;
  # ports.minecraft-java.reverseProxy.domain = "axelhax.net";
  # ports.minecraft-bedrock.reverseProxy.domain = "axelhax.net";

  # --- HYTALE
  # services.hytale-server.enable = true;
  # ports.hytale.reverseProxy.domain = "axelhax.net";

  # --- AUTHELIA
  services.authelia = {
    id = "authelia";
    enable = true;
    require.ldap-server = servicesById.lldap.provide.ldap-server;
    require.mail-server = servicesById.snm.provide.mail-server;
    require.oidc-clients = builtins.foldl' (acc: e: acc ++ servicesById.${e}.provide.oidc-clients) [] [
      "headscale"
      "opencloud"
    ];
  };
  ports.authelia.reverseProxy.domain = "auth.axelhax.net";

  # --- LLDAP
  services.lldap = {
    id = "lldap";
    enable = true;
    require.ldap-clients = builtins.foldl' (acc: e: acc ++ servicesById.${e}.provide.ldap-clients) [] [
      "snm"
      "authelia"
      "opencloud"
      "jellyfin"
    ];
  };
  ports.ldaps.reverseProxy.domain = "ldap.axelhax.net";
  # ports.ldaps.reverseProxy.hidden = true; # TODO: currently broken
  ports.lldap.reverseProxy.domain = "users.axelhax.net";

  # --- NGINX HTTP
  services.staticWebsites = {
    enable = true;
    sites = ["axelhax" "transit-vis"];
  };
  ports.staticWebsites-axelhax.reverseProxy.domain = "axelhax.net";
  ports.staticWebsites-transit-vis.reverseProxy.domain = "transit-vis.axelhax.net";

  # --- OPENCLOUD
  services.opencloud = {
    id = "opencloud";
    enable = true;
    require.ldap-server = servicesById.lldap.provide.ldap-server;
    require.oidc-server = servicesById.authelia.provide.oidc-server;
  };
  ports.opencloud.reverseProxy.domain = "cloud.axelhax.net";

  # --- JELLYFIN
  services.jellyfin = {
    id = "jellyfin";
    enable = true;
    require.ldap-server = servicesById.lldap.provide.ldap-server;
  };
  ports.jellyfin.reverseProxy.domain = "media.axelhax.net";

  # --- NFS
  # services.nfs = {
  #   enable = true;
  #   serve.husk = "/mnt/husk";
  # };
}
