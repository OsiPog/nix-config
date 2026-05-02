# This is a special nix module. It is imported into `networking.hosts.<name>` of every nixos configuration.
# So that each host can see the network configuration of all other hosts.
{...}: {
  vpn.ip = "100.64.0.4";
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDYdr33vJvtTnrSDiEhCUkc0fL7GyrZG9UEL8zjaKJpU root@floating-trees";
    allowConnectionsFrom = ["dead-voxel" "biome-fest"];
  };
  stateDirs = [
    "/mnt/husk"
  ];

  # --- DNSMASQ
  services.dnsmasq.enable = true;

  # --- RESTIC
  services.backup = {
    enable = true;
    server = {
      enable = true;
      repository = "/mnt/blaze";
    };
  };

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
  services.hytale-server.enable = true;
  ports.hytale.reverseProxy = {
    enable = true;
    domain = "axelhax.net";
  };

  # --- AUTHELIA
  services.authelia = {
    enable = true;
    integrations = {
      ldap.enable = true;
      mail = {
        enable = true;
        host = "haunt-muskie";
      };
    };
  };
  ports.authelia.reverseProxy = {
    enable = true;
    domain = "auth.axelhax.net";
  };

  # --- LLDAP
  services.lldap = {
    enable = true;
    integrations.mail = {
      enable = true;
      host = "haunt-muskie";
    };
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
  services.staticWebsites = {
    enable = true;
    sites = ["axelhax"];
  };
  ports.staticWebsites-axelhax.reverseProxy = {
    enable = true;
    domain = "axelhax.net";
  };

  # --- OPENCLOUD
  services.opencloud = {
    enable = true;
    integrations.ldap.enable = true;
  };
  ports.opencloud.reverseProxy = {
    enable = true;
    domain = "cloud.axelhax.net";
  };

  # --- JELLYFIN
  services.jellyfin = {
    enable = true;
    integrations.ldap.enable = true;
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
