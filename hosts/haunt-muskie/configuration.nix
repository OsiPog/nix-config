{
  flake,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = with flake.nixosModules; [
    ./hardware-configuration.nix
    shared

    disko-basic
  ];

  system.stateVersion = "25.11";
}
