{
  flake,
  pkgs,
  lib,
  inputs,
  config,
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
    hoglin-drive
    makemkv
    optnix

    ../../users/osi

    # ./vm-gpu-passthrough.nix

    # for secure boot and windows option in bootloader
    ./modules/limine.nix
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

  # for nfs
  users.extraGroups.husk.members = ["osi"];

  services.sunshine = {
    autoStart = true;
    enable = true;
    capSysAdmin = true;
  };

  networking.firewall.allowedTCPPorts = [7999 3080];

  # llama.cpp model/runtime config. host/port/api-key are set by the llamacpp
  # network module; these are the model-specific runtime flags.
  services.llama-cpp = {
    package = pkgs.llama-cpp-vulkan;
    settings = {
      hf-repo = "unsloth/Qwen3.6-35B-A3B-GGUF";
      main-gpu = 0;
      n-gpu-layers = 999;
      n-cpu-moe = 19;
      no-mmap = true;
      ctx-size = 262144;
      reasoning = "off";
      cache-type-k = "q8_0";
      cache-type-v = "q4_0";
      flash-attn = "on";
      fit = "off";
    };
  };

  # Don't change, will break things!
  system.stateVersion = "25.11";
}
