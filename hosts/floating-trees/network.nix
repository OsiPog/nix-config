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
  ports = {
    minecraft-java.reverseProxy = {
      enable = true;
      domain = "axelhax.net";
    };
    minecraft-bedrock.reverseProxy = {
      enable = true;
      domain = "axelhax.net";
    };
    authelia.reverseProxy = {
      enable = true;
      domain = "auth.axelhax.net";
    };
    portunus.reverseProxy = {
      enable = true;
      domain = "users.axelhax.net";
      # hidden = true; # TODO: currently broken
    };
    ldaps.reverseProxy = {
      enable = true;
      domain = "ldap.axelhax.net";
      # hidden = true; # TODO: currently broken
    };
  };
  services = {
    dnsmasq.enable = true;
    backup = {
      enable = true;
      server = {
        enable = true;
        repository = "/mnt/blaze";
      };
    };
    minecraft-server.enable = true;
    authelia = {
      enable = true;
      integrations = {
        ldap.enable = true;
        smtp = {
          enable = true;
          host = "haunt-muskie";
        };
      };
    };
    portunus = {
      enable = true;
      integrations.smtp = {
        enable = true;
        host = "haunt-muskie";
      };
    };
  };
}
