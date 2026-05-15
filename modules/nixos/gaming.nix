{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.default
    inputs.nix-flatpak.nixosModules.nix-flatpak
  ];

  environment.systemPackages = with pkgs; [
    wine-wayland
    # (retroarch.withCores (cores:
    #   with cores; [
    #     # citra-canary
    #     dolphin
    #   ]))
    # ryubing
    (writeShellApplication {
      name = "smart-gamescope";
      runtimeInputs = [config.programs.gamescope.package];
      text = ''
        # if we are inside gamescope already do nothing
        if [ -n "''${ENABLE_GAMESCOPE_WSI}" ]; then
          exec "$@"
        # otherwise wrap command with gamescope
        else
          gamescope -w 1920 -h 1080 --xwayland-count 2 --force-grab-cursor --steam -- "$@"
        fi
      '';
    })
  ];

  # # For retroarch
  # nixpkgs.config.permittedInsecurePackages = [
  #   "mbedtls-2.28.10"
  # ];

  hardware.graphics.enable32Bit = true;

  nixpkgs.config.allowUnfree = true;

  programs = {
    gamescope = {
      enable = true;
      capSysNice = false;
    };
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };
  };

  home-manager.sharedModules = [
    ({...}: {
      programs.lutris.enable = true;

      xdg.desktopEntries.steam-gamescope = {
        icon = "steam";
        name = "Steam Gamescope";
        exec = "smart-gamescope steam -tenfoot";
      };
    })
  ];

  # gaming flatpaks
  services.flatpak = {
    enable = true;
    packages = [
      # Hytale Launcher
      # rec {
      #   appId = "com.hypixel.HytaleLauncher";
      #   sha256 = "sha256-ETQntlv7zfuWBysF5eNeAONBrCaa6l6RjvOPh6kbSEI=";
      #   bundle = toString (pkgs.fetchurl {
      #     url = "https://launcher.hytale.com/builds/release/linux/amd64/hytale-launcher-latest.flatpak";
      #     inherit sha256;
      #   });
      # }
      # Retro Deck emulation stuff
      "net.retrodeck.retrodeck"
    ];
  };
}
