{
  flake,
  lib,
  ...
}: {
  imports = with flake.nixosModules; [
    ./hardware-configuration.nix
    shared

    disko-basic
  ];

  system.stateVersion = "25.11";
}
