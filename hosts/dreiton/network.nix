# This is a special nix module. It is imported into `networking.hosts.<name>` of every nixos configuration.
# So that each host can see the network configuration of all other hosts.
{...}: {
  vpn.ip = "100.64.0.7";
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK44GxBLg68sWe2OFiX69Mx4mP7WLI7NqJtspzWj2isi root@dreiton";
    allowConnectionsFrom = ["dead-voxel" "floating-trees"];
  };
  services = {
    # ...
  };
}
