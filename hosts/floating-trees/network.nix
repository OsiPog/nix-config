# This is a special nix module. It is imported into `networking.hosts.<name>` of every nixos configuration.
# So that each host can see the network configuration of all other hosts.
{...}: {
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDYdr33vJvtTnrSDiEhCUkc0fL7GyrZG9UEL8zjaKJpU root@floating-trees";
    allowConnectionsFrom = ["dead-voxel" "biome-fest"];
  };
  services = {
    # portunus = {
    #   enable = true;
    #   settings.domain = "axelhax";
    # };
    minecraft-server = {
      enable = true;
      ports = {
        game = {
          reverseProxy = {
            enable = true;
            host = "haunt-muskie";
            method = "stream";
          };
          port = 25565;
        };
        bedrock = {
          reverseProxy = {
            enable = true;
            host = "haunt-muskie";
            method = "stream";
            udp = true;
          };
          port = 19132;
        };
      };
    };
  };
}
