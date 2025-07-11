{inputs, ...}: {
  # The Lenovo laptop was not set up using disko, so we are defining it here in pure nixpkgs options
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/7aefc206-56e9-4426-a19e-f215dc813886";
    fsType = "ext4";
  };

  boot.initrd = {
    luks.devices."luks-ff0fdffe-9e8d-4956-92ef-ce2317629a32" = {
      device = "/dev/disk/by-uuid/ff0fdffe-9e8d-4956-92ef-ce2317629a32";
      # About key enrolling: https://nixos.org/manual/nixos/stable/#sec-luks-file-systems-fido2
      # sudo systemd-cryptenroll --fido2-device=auto --fido2-with-user-presence=false --fido2-with-user-verification=true /dev/disk/by-uuid/ff0fdffe-9e8d-4956-92ef-ce2317629a32
      crypttabExtraOpts = [
        "fido2-device=auto"
        "token-timeout=5"
        # you can always just restart the machine and the counter will be reset, so I can also just give infinite tries
        "tries=0"
        # do not crash when idle
        "x-systemd.device-timeout=100h"
      ];
    };
    systemd = {
      enable = true;
      fido2.enable = true;
      tpm2.enable = false;
    };
    luks.fido2Support = false; # because systemd
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/8DFC-47EE";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022" "noatime"];
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  # The laptop has a fingerprint sensor
  # Make sure to patch the firmware: https://github.com/goodix-fp-linux-dev/goodix-fp-dump
  services.fprintd.package = inputs.libfprint-goodix-55b4.packages.x86_64-linux.fprintd;

  # networking.useDHCP = lib.mkDefault true;
}
