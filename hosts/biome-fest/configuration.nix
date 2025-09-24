{
  config,
  flake,
  inputs,
  ...
}: {
  imports = with flake.nixosModules; [
    shared

    ./hardware-configuration.nix

    (
      {pkgs, ...}: {
        boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
      }
    )

    allow-some-unfree
    fingerprint
    laptop
    monitors
    obs-studio
    printing
    sound
    speicherfresser
    tuigreet
    podman
    nix-access-tokens

    ../../users/osi
  ];

  boot.initrd = {
    # About key enrolling: https://nixos.org/manual/nixos/stable/#sec-luks-file-systems-fido2
    # sudo systemd-cryptenroll --fido2-device=auto --fido2-with-user-presence=false --fido2-with-user-verification=true /dev/disk/by-uuid/ff0fdffe-9e8d-4956-92ef-ce2317629a32
    luks.devices."luks-ff0fdffe-9e8d-4956-92ef-ce2317629a32".crypttabExtraOpts = [
      "fido2-device=auto"
      "token-timeout=5"
      # you can always just restart the machine and the counter will be reset, so I can also just give infinite tries
      "tries=0"
    ];

    systemd = {
      enable = true;
      fido2.enable = true;
      tpm2.enable = false;
    };
    luks.fido2Support = false; # because systemd
  };

  # The laptop has a fingerprint sensor
  # Make sure to patch the firmware: https://github.com/goodix-fp-linux-dev/goodix-fp-dump
  services.fprintd.package = inputs.libfprint-goodix-55b4.packages.x86_64-linux.fprintd;

  # Swapfile needed because low raw
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  # Don't change, will break things.
  system.stateVersion = "23.11"; # Did you read the comment?
}
