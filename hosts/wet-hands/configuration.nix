{
  flake,
  pkgs,
  lib,
  ...
}: {
  imports = with flake.nixosModules; [
    ./hardware-configuration.nix
    shared

    disko-basic

    steamos

    theme-prismarine
  ];

  disko.devices.disk.disk1.device = "/dev/nvme0n1";

  jovian = {
    devices.steamdeck.enable = true;
  };

  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/evenok-dark.yaml";

  system.stateVersion = "25.11";
}
