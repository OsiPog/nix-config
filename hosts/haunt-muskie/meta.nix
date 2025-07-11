{
  ip-address = "10.12.21.200";
  ssh = {
    public-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAp5UxVvqO6i0Jp4W68CqYnKh5yEB+6ZzS987dT/eNtL root@haunt-muskie";
    allow-connections-from = ["biome-fest"];
  };
}
