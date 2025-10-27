{...}: {
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKShjod8+H+fuNp9e6gjifRfu8/vdEwKO837MmFgViil root@blind-spots";
    allowConnectionsFrom = ["biome-fest" "dead-voxel"];
  };
  services = {
    forgejo = {
      enable = true;
      ports.web = {
        port = 2000;
        reverseProxy = {
          enable = true;
          host = "haunt-muskie";
          subdomain = "git";
        };
      };
    };
    nextcloud = {
      enable = true;
      ports.web = {
        port = 80;
        reverseProxy = {
          enable = true;
          host = "haunt-muskie";
          subdomain = "cloud";
        };
      };
    };
    authelia = {
      enable = false;
      ports.web = {
        port = 6000;
        reverseProxy = {
          enable = true;
          host = "haunt-muskie";
          subdomain = "auth";
        };
      };
    };
    portunus = {
      enable = true;
      ports.web = {
        port = 7000;
        reverseProxy = {
          enable = true;
          host = "haunt-muskie";
          subdomain = "ldap";
        };
      };
    };
  };
}
