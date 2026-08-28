{
  config,
  flake,
  inputs,
  pkgs,
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

    fingerprint
    laptop
    obs-studio
    printing
    sound
    tuigreet
    podman
    nix-access-tokens
    gaming
    hoglin-drive
    windows-vm

    # Numark NS6 DJ controller: userspace Ploytec driver publishing an ALSA
    # MIDI port, plus the udev rule that starts it when the deck powers on.
    inputs.ns6.nixosModules.default

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
  # TODO: currently broken
  # services.fprintd.package = inputs.libfprint.packages.x86_64-linux.fprintd;

  # Swapfile needed because low raw
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  # init with: sudo waydroid init -s GAPPS -f
  virtualisation.waydroid.enable = true;

  services.ns6.enable = true;

  environment.systemPackages = [
    pkgs.mixxx
    pkgs.usbutils # temporary, for the NS6 capture work below
  ];

  # --- Temporary: USB traffic capture for reverse-engineering the Numark NS6.
  # Remove once its driver works. See ~/vm/README.md and ~/ns6-rs.
  #
  # usbmon is the kernel's USB tracer. It lets the host record every transfer a
  # passed-through device makes, including those issued by a Windows guest's
  # driver, which is what makes an exact diff against our own driver possible.
  boot.kernelModules = ["usbmon"];
  # --- End temporary

  systemd.services.fix-touchpad-after-resume = {
    description = "Rebind Synaptics touchpad after resume to restore multitouch";
    wantedBy = ["post-resume.target"];
    after = ["post-resume.target"];
    script = ''
      echo i2c-SYNA2BA6:00 > /sys/bus/i2c/drivers/i2c_hid_acpi/unbind
      echo i2c-SYNA2BA6:00 > /sys/bus/i2c/drivers/i2c_hid_acpi/bind
    '';
    serviceConfig.Type = "oneshot";
  };

  services.sunshine = {
    autoStart = true;
    enable = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  # Don't change, will break things.
  system.stateVersion = "23.11"; # Did you read the comment?
}
