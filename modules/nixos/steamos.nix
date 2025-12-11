{
  inputs,
  flake,
  lib,
  ...
}: {
  imports = [
    inputs.jovian-nixos.nixosModules.default

    (flake.lib.mkUserModule "steam")

    ./gaming.nix
  ];

  nixpkgs.config.allowUnfree = true;

  programs.gamescope.enable = lib.mkForce false;

  jovian = {
    steam = {
      enable = true;
      user = "steam";
      autoStart = true;
      desktopSession = "gamescope-wayland";
    };
  };
}
