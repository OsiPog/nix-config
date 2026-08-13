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

  programs.gamescope.enable = lib.mkForce false;

  jovian = {
    steam = {
      enable = true;
      user = "steam";
      autoStart = true;
      desktopSession = "plasma";
    };
  };

  services.desktopManager.plasma6.enable = true;
}
