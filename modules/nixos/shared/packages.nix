{
  pkgs,
  inputs,
  lib,
  ...
}: {
  imports = with inputs; [
    flake-programs-sqlite.nixosModules.programs-sqlite
  ];
  environment.systemPackages = with pkgs; [
    fastfetch # System info
    bat # Better cat
    jq # tool to parse json
    usbutils # for lsusb and such
    busybox # basic commands
    ripgrep
    gitMinimal
    helix
    btop
    nnn
  ];
  environment.variables = {
    EDITOR = lib.mkOverride 900 "hx";
    VISUAL = lib.mkOverride 900 "hx";
    NNN_USE_EDITOR = 1;
  };

  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    silent = true;
    nix-direnv.enable = true;
  };
  services.udisks2.enable = true;

  # When a command is entered that does not exist a nice message is presented
  programs.command-not-found.enable = true;
}
