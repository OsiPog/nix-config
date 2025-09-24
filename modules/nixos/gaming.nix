{
  inputs,
  flake,
  pkgs,
  ...
}: {
  imports = [
    inputs.jovian-nixos.nixosModules.default
    inputs.home-manager.nixosModules.default
  ];

  environment.systemPackages = with pkgs; [
    lutris
  ];

  hardware.graphics.enable32Bit = true;

  nixpkgs.config.allowUnfree = true;

  jovian.steam.enable = true;
}
