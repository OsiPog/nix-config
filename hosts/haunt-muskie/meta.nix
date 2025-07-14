{
  ip-address = "10.12.21.202";
  ssh = {
    public-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAcSqngrHbdtiCGzPmt6peImIQfYek/WLcaXIwrhN5oS root@haunt-muskie";
    allow-connections-from = ["biome-fest"];
  };
}