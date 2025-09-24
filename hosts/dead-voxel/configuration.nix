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
    gaming
    podman
    nix-access-tokens

    ../../users/osi
  ];

  boot.initrd.systemd.enable = true;

  hardware.graphics.enable = true;
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia.open = true; # see the note above

  jovian.steam.user = "osi";

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  services.desktopManager.plasma6.enable = true;

  # Don't change, will break things!
  system.stateVersion = "25.11";
}
