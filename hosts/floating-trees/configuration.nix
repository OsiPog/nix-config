{flake, ...}: {
  imports = with flake.nixosModules; [
    ./hardware-configuration.nix
    shared

    disko-fsd

    drive-blaze-husk
  ];

  disko.devices.disk.disk1.device = "/dev/disk/by-id/ata-EDILOCA_ES106_1TB_AA000000000000050186";

  # Don't change, will break things!
  system.stateVersion = "25.11";
}
