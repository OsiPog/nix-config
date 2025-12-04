{...}: {
  vpn.ip = "100.64.0.3";
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL7bzk6u4CLkDp9b5u0btUCaEw2SKb33/5o6LBZkbRHJ root@wet-hands";
    allowConnectionsFrom = ["biome-fest" "dead-voxel"];
  };
}
