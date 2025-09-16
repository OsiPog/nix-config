{inputs, ...}: {
  imports = [
    inputs.jovian-nixos.nixosModules.default
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
