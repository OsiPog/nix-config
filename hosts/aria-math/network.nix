{...}: {
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFLZwgyWl1tOyvrIQoOaU9+O8FR3Ia/goUjSgeWwsyWb root@aria-math";
    allowConnectionsFrom = ["dead-voxel"];
  };
  services = {
    minecraft-server = {
      enable = false;
      ports.game = {
        port = 25565;
        reverseProxy = {
          enable = true;
          host = "haunt-muskie";
        };
      };
    };
  };
}
