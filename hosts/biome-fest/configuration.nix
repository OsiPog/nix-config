{ config, flake, ... }:
{
  imports = with flake.nixosModules; [
    shared

    ./hardware-configuration.nix

    # (
    #   { pkgs, ... }:
    #   {
    #     boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
    #   }
    # )

    allow-some-unfree
    fingerprint
    laptop
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

  # services.desktopManager.plasma6.enable = true;

  # Don't change, will break things.
  system.stateVersion = "23.11"; # Did you read the comment?
}
