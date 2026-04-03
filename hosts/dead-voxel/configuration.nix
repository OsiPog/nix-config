{
  flake,
  pkgs,
  lib,
  ...
}: {
  imports = with flake.nixosModules; [
    ./hardware-configuration.nix
    shared

    # (
    #   {pkgs, ...}: {
    #     boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
    #   }
    # )

    allow-some-unfree
    obs-studio
    printing
    sound
    gaming
    podman
    nix-access-tokens
    tuigreet

    ../../users/osi

    ./vm-gpu-passthrough.nix
  ];

  boot.initrd = {
    # About key enrolling: https://nixos.org/manual/nixos/stable/#sec-luks-file-systems-fido2
    # sudo systemd-cryptenroll --fido2-device=auto --fido2-with-user-presence=false --fido2-with-user-verification=true /dev/disk/by-uuid/eded9eca-c0eb-4474-a0b5-1103acf72ed4
    luks.devices."luks-eded9eca-c0eb-4474-a0b5-1103acf72ed4".crypttabExtraOpts = [
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
    luks.fido2Support = false;
  };

  stylix = {
    base16Scheme = "${pkgs.base16-schemes}/share/themes/oceanicnext.yaml";
    image = ../../modules/nixos/theme-prismarine/nms.jpg;
  };

  hardware.bluetooth.enable = true;

  # Swapfile needed because low raw
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  hardware.amdgpu = {
    initrd.enable = true;
    opencl.enable = true;
  };

  boot.kernelParams = [
    "video=HDMI-A-1:2560x1440"
    "video=HDMI-A-2:1600x900,panel_orientation=right_side_up"
  ];

  # init with: sudo waydroid init -s GAPPS -f
  virtualisation.waydroid.enable = true;

  environment.systemPackages = with pkgs; [
    makemkv
  ];

  # for makemkv
  boot.kernelModules = ["sg"];

  # for nfs
  users.extraGroups.husk.members = ["osi"];

  # Don't change, will break things!
  system.stateVersion = "25.11";
}
