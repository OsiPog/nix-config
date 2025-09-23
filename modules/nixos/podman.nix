{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (builtins) attrNames;
  inherit (lib) pipe;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.lists) findFirst;

  inList = e: list: (findFirst (x: x == e) null list) != null;
in {
  environment.systemPackages = [
    pkgs.podman-compose
  ];
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
  };

  # Put all users that have the wheel group also into the podman group
  users.extraGroups.podman.members = pipe config.users.users [
    (filterAttrs (_: value: inList "wheel" value.extraGroups))
    attrNames
  ];
}
