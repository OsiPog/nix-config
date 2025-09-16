{
  inputs,
  flake,
  ...
}: {
  imports = [
    inputs.jovian-nixos.nixosModules.default

    (flake.lib.mkUserModule "steam")
  ];

  nixpkgs.config.allowUnfree = true;

  jovian = {
    steam = {
      enable = true;
      user = "steam";
      autoStart = true;
      desktopSession = "gamescope-wayland";
    };
  };
}
