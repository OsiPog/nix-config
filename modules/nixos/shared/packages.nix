{
  pkgs,
  inputs,
  ...
}:
{
  imports = with inputs; [
    flake-programs-sqlite.nixosModules.programs-sqlite
  ];
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

  # When a command is entered that does not exist a nice message is presented
  programs.command-not-found.enable = true;
}
