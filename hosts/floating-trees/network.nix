# This is a special nix module. It is imported into `networking.hosts.<name>` of every nixos configuration.
# So that each host can see the network configuration of all other hosts.
{servicesById, ...}: {
  vpn.ip = "100.64.0.4";
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDYdr33vJvtTnrSDiEhCUkc0fL7GyrZG9UEL8zjaKJpU root@floating-trees";
    allowConnectionsFrom = ["dead-voxel" "biome-fest"];
  };

  # --- DNSMASQ
  # services.dnsmasq.enable = true;

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
  # ports.minecraft-java.reverseProxy = {
  #   enable = true;
  #   domain = "axelhax.net";
  # };
  # ports.minecraft-bedrock.reverseProxy = {
  #   enable = true;
  #   domain = "axelhax.net";
  # };

  # --- HYTALE
  # services.hytale-server.enable = true;
  # ports.hytale.reverseProxy = {
  #   enable = true;
  #   domain = "axelhax.net";
  # };

  # --- AUTHELIA
  services.authelia = {
    id = "oidc-provider";
    enable = true;
    require.ldap-server = servicesById.ldap-server.provide.ldap-server;
    require.oidc-clients = builtins.foldl' (acc: e: acc ++ servicesById.${e}.provide.oidc-clients) [] [
      "headscale"
    ];
  };
  ports.authelia.reverseProxy = {
    enable = true;
    domain = "auth.axelhax.net";
  };

  # --- LLDAP
  services.lldap = {
    id = "ldap-server";
    enable = true;
    require.ldap-clients = builtins.foldl' (acc: e: acc ++ servicesById.${e}.provide.ldap-clients) [] [
      "email"
      "oidc-provider"
      "cloud"
      "media-server"
    ];
  };
  ports.ldaps.reverseProxy = {
    enable = true;
    domain = "ldap.axelhax.net";
    # hidden = true; # TODO: currently broken
  };
  ports.lldap.reverseProxy = {
    enable = true;
    domain = "users.axelhax.net";
  };

  # --- NGINX HTTP
  # services.staticWebsites = {
  #   enable = true;
  #   sites = ["axelhax" "transit-vis"];
  # };
  # ports.staticWebsites-axelhax.reverseProxy = {
  #   enable = true;
  #   domain = "axelhax.net";
  # };
  # ports.staticWebsites-transit-vis.reverseProxy = {
  #   enable = true;
  #   domain = "transit-vis.axelhax.net";
  # };

  # --- OPENCLOUD
  services.opencloud = {
    id = "cloud";
    enable = true;
    require.ldap-server = servicesById.ldap-server.provide.ldap-server;
  };
  ports.opencloud.reverseProxy = {
    enable = true;
    domain = "cloud.axelhax.net";
  };

  # --- JELLYFIN
  services.jellyfin = {
    id = "media-server";
    enable = true;
    require.ldap-server = servicesById.ldap-server.provide.ldap-server;
  };
  ports.jellyfin.reverseProxy = {
    enable = true;
    domain = "media.axelhax.net";
  };

  # --- NFS
  # services.nfs = {
  #   enable = true;
  #   serve.husk = "/mnt/husk";
  # };
}
