{
  inputs,
  pkgs,
  lib,
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
        exec = "gamescope -w 1920 -h 1080 --xwayland-count 2 --force-grab-cursor --steam -- steam -tenfoot";
      };
    })
  ];

  # gaming flatpaks
  services.flatpak = {
    enable = true;
    packages = [
      # Hytale Launcher
      rec {
        appId = "com.hypixel.HytaleLauncher";
        sha256 = "sha256-Lt9agnXzWyGH6NNtfLJFNrpFVrhl+3bYzbirM/e9iT4=";
        bundle = toString (pkgs.fetchurl {
          url = "https://launcher.hytale.com/builds/release/linux/amd64/hytale-launcher-latest.flatpak";
          inherit sha256;
        });
      }
      # Retro Deck emulation stuff
      "net.retrodeck.retrodeck"
    ];
  };
}
