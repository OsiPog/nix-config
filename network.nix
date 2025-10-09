# This file defines how all hosts are connected and which services are running where. You can find the option definitions
# in modules/nixos/shared/network/default.nix.
{inputs, ...}: {
  imports = with inputs.nix-config-private.nixosModules; [
    taswell-domain
  ];

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
          allowConnectionsFrom = ["biome-fest" "dead-voxel"];
        };
        reverseProxy = {
          enable = true;
          domain = "kazuka.zip";
        };
      };
      wet-hands = {
        ssh = {
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL7bzk6u4CLkDp9b5u0btUCaEw2SKb33/5o6LBZkbRHJ root@wet-hands";
          allowConnectionsFrom = ["biome-fest" "dead-voxel"];
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
          allowConnectionsFrom = ["biome-fest" "dead-voxel"];
        };
      };
      taswell = {
        reverseProxy = {
          enable = true;
          # domain = "..."; # set by private taswell-domain module
        };
        ssh = {
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO58gd6nHEMAdi8pth1PHytxa32DBJSD4s/EuN20zu/o root@taswell";
          allowConnectionsFrom = ["biome-fest"];
        };
      };
    };
    services = {
      forgejo = {
        enable = true;
        host = "blind-spots";
        port = 2000;
        reverseProxy = {
          enable = true;
          host = "haunt-muskie";
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
      nextcloud = {
        enable = true;
        host = "blind-spots";
        port = 80;
        reverseProxy = {
          enable = true;
          host = "haunt-muskie";
          subdomain = "cloud";
        };
      };
      authelia = {
        enable = true;
        host = "blind-spots";
        port = 6000;
        reverseProxy = {
          enable = true;
          host = "haunt-muskie";
          subdomain = "auth";
        };
      };
    };
  };
}
