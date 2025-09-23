{flake, ...}: {
  imports = with flake.nixosModules; [
    ./hardware-configuration.nix
    shared

    (
      {pkgs, ...}: {
        boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
      }
    )

    allow-some-unfree
    monitors
    obs-studio
    printing
    sound
    speicherfresser
    steam
    tuigreet
    podman
    nix-access-tokens

    ../../users/osi
  ];

  boot.initrd.systemd.enable = true;

  # Don't change, will break things!
  system.stateVersion = "25.11";
}
