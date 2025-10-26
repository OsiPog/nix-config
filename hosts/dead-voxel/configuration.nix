{
  flake,
  pkgs,
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
    monitors
    obs-studio
    printing
    sound
    speicherfresser
    gaming
    podman
    nix-access-tokens
    nvidia-ampere

    ../../users/osi
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

  jovian.steam.user = "osi";

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    settings = {
      Users = {
        HideUsers = "leaf";
        RememberLastUser = true;
        RememberLastSession = true;
      };
    };
  };

  stylix = {
    base16Scheme = "${pkgs.base16-schemes}/share/themes/oceanicnext.yaml";
    image = ../../modules/nixos/theme-prismarine/nms.jpg;
  };

  # slower mouse
  home-manager.users.osi.wayland.windowManager.hyprland.settings.input.sensitivity = -0.5;

  # Don't change, will break things!
  system.stateVersion = "25.11";
}
