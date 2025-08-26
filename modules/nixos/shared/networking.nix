{
  hostName,
  lib,
  ...
}:
{
  networking = {
    hostName = hostName;
    useNetworkd = lib.mkForce false;
    networkmanager.enable = true;
    firewall.enable = true;
  };
}
