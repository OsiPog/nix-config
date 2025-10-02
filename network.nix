# This file defines how all hosts are connected and which services are running where. You can find the option definitions
# in modules/nixos/shared/network-options.nix.
{...}: {
  network = {
    hosts = {
      biome-fest = {
        ssh = {
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDIcVpuDI9fFcNWeMEHelbaItqQJwmAkibSFR+nBhxng root@biome-fest";
          allowConnectionsFrom = ["dead-voxel"];
        };
      };
      haunt-muskie = {
        ssh = {
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAcSqngrHbdtiCGzPmt6peImIQfYek/WLcaXIwrhN5oS root@haunt-muskie";
          allowConnectionsFrom = ["biome-fest"];
        };
        reverseProxy = {
          enable = true;
          domain = "kazuka.zip";
        };
      };
      wet-hands = {
        ssh = {
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL7bzk6u4CLkDp9b5u0btUCaEw2SKb33/5o6LBZkbRHJ root@wet-hands";
          allowConnectionsFrom = ["biome-fest"];
        };
      };
      dead-voxel = {
        ssh = {
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICoAlhl10PYwDxDLVhCZVru3AmAbGTdITdoGcrklDaTx root@dead-voxel";
          allowConnectionsFrom = ["biome-fest"];
        };
      };
      blind-spots = {
        ssh = {
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKShjod8+H+fuNp9e6gjifRfu8/vdEwKO837MmFgViil root@blind-spots";
          allowConnectionsFrom = ["biome-fest"];
        };
      };
    };
    services = {
      forgejo = {
        enable = true;
        host = "haunt-muskie";
        port = 2000;
        reverseProxy = {
          enable = true;
          subdomain = "git";
        };
      };
      vsftpd = {
        enable = true;
        host = "haunt-muskie";
        port = 21;
      };
      headscale = {
        enable = true;
        host = "haunt-muskie";
        port = 8081;
        reverseProxy = {
          enable = true;
          subdomain = "vpn";
          extraVirtualHostsConfig = {
            locations."/".proxyWebsockets = true;
          };
        };
      };
    };
  };
}
