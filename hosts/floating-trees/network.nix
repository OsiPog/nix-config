# This is a special nix module. It is imported into `networking.hosts.<name>` of every nixos configuration.
# So that each host can see the network configuration of all other hosts.
{...}: {
  vpn.ip = "100.64.0.4";
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDYdr33vJvtTnrSDiEhCUkc0fL7GyrZG9UEL8zjaKJpU root@floating-trees";
    allowConnectionsFrom = ["dead-voxel" "biome-fest"];
  };
  services = {
    dnsmasq.enable = true;
    backup = {
      enable = true;
      settings = {
        paths = [
          "/mnt/husk" # big drive
        ];
        server = {
          enable = true;
          repository = "/mnt/blaze";
        };
      };
    };
    # portunus = {
    #   enable = true;
    #   settings.domain = "axelhax";
    # };
    minecraft-server = {
      enable = true;
      ports = {
        java = {
          reverseProxy = {
            enable = true;
            host = "haunt-muskie";
          };
        };
        bedrock = {
          reverseProxy = {
            enable = true;
            host = "haunt-muskie";
          };
        };
      };
    };
  };
}
