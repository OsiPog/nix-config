{ config, flake, ... }:
{
  imports = with flake.nixosModules; [
    shared

    ./hardware-configuration.nix

    (
      { pkgs, ... }:
      {
        boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
      }
    )

    allow-some-unfree
    fingerprint
    laptop
    monitors
    networking
    obs-studio
    printing
    sound
    speicherfresser
    steam
    tuigreet
    # podman

    ../../users/osi
  ];

  # services.desktopManager.plasma6.enable = true;

  sops.secrets."api-keys/nix-access-tokens" = {
    owner = "osi";
  };
  nix.extraOptions = ''
    !include ${config.getSopsFile "api-keys/nix-access-tokens"}    
  '';

  # Don't change, will break things.
  system.stateVersion = "23.11"; # Did you read the comment?
}
