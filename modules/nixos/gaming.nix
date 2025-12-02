{
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = [
    inputs.jovian-nixos.nixosModules.default
    inputs.home-manager.nixosModules.default
  ];

  environment.systemPackages = with pkgs; [
    wine-wayland
    (retroarch.withCores (cores:
      with cores; [
        # citra-canary
        dolphin
      ]))
    ryubing
  ];

  # For retroarch
  nixpkgs.config.permittedInsecurePackages = [
    "mbedtls-2.28.10"
  ];

  hardware.graphics.enable32Bit = true;

  nixpkgs.config.allowUnfree = true;

  jovian.steam.enable = true;
  programs.steam.localNetworkGameTransfers.openFirewall = true;

  home-manager.sharedModules = [
    ({...}: {
      programs.lutris.enable = true;
    })
  ];
}
