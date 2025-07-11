{
  pkgs,
  lib,
  self,
  inputs,
  ...
}: let
  inherit (lib) mkDefault;
  inherit (lib.attrsets) mapAttrs;
in {
  imports = with inputs; [
    home-manager.nixosModules.default
    nixos-facter-modules.nixosModules.facter
  ];

  # --- NIX SETTINGS AND OPTIONS
  nix = {
    # enable flakes and nix command
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Automatic garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  # Disable generation of man caches
  documentation.man.generateCaches = false;

  nixpkgs.overlays = with inputs; [
    # Add packages of the flakes in an overlay
    (
      final: prev: let
        stable = nixpkgs-stable.legacyPackages.${prev.system};
      in {
        # to access stable packages
        inherit stable;

        # stable packages
        auto-cpufreq = stable.auto-cpufreq;

        # custom flake packages
        matcha = matcha.packages.${prev.system}.default;
        self = outputsEachSystem.packages.${prev.system};
      }
    )
  ];

  # --- HOME MANAGER
  home-manager = {
    extraSpecialArgs = {
      inherit inputs;
      inherit self;
    };
    useGlobalPkgs = true;
    backupFileExtension = "backupFileExtension";

    # Home manager settings for every user
    sharedModules = [
      ({nixosConfig, ...}: {
        # Let home manager manage itself
        programs.home-manager.enable = true;
        # OpenSSH
        programs.ssh.enable = true;
        # As home manager is installed on each system the same time as home manager the state version is the same
        home.stateVersion = nixosConfig.system.stateVersion;
      })
    ];
  };

  # --- ESSENTIAL PACKAGES
  environment.systemPackages = with pkgs; [
    fastfetch # System info
    bat # Better cat
    atool # Extract any archive
    jq # tool to parse json
    usbutils # for lsusb and such
    ripgrep
    gitMinimal
  ];
  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    silent = true;
    nix-direnv.enable = true;
  };
  services.udisks2.enable = true;

  # --- LOCALE
  i18n = {
    defaultLocale = mkDefault "en_US.UTF-8";
    # Home sweet home german formats
    extraLocaleSettings = mapAttrs (_: mkDefault) {
      LC_ADDRESS = "de_DE.UTF-8";
      LC_IDENTIFICATION = "de_DE.UTF-8";
      LC_MEASUREMENT = "de_DE.UTF-8";
      LC_MONETARY = "de_DE.UTF-8";
      LC_NAME = "de_DE.UTF-8";
      LC_NUMERIC = "de_DE.UTF-8";
      LC_PAPER = "de_DE.UTF-8";
      LC_TELEPHONE = "de_DE.UTF-8";
      LC_TIME = "de_DE.UTF-8";
    };
  };
  time.timeZone = mkDefault "Europe/Berlin";
  services.xserver = {
    xkb.layout = "us,de";
    xkb.variant = "colemak,";
    xkb.options = "grp:win_space_toggle";
  };
  console.keyMap = "colemak";

  # --- DEFAULT SHELL
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # disable the greeting
      set fish_greeting
    '';
  };
  users.defaultUserShell = pkgs.fish;

  # --- BOOTLOADER
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 7;
  };

  # --- COMMAND NOT FOUND
  # When a command is entered that does not exist a nice message is presented
  programs.command-not-found.enable = true;
}
