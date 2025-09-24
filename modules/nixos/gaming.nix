{
  inputs,
  flake,
  ...
}: {
  imports = [
    inputs.jovian-nixos.nixosModules.default
    inputs.home-manager.nixosModules.default
  ];

  nixpkgs.config.allowUnfree = true;

  jovian = {
    steam = {
      enable = true;
      user = "steam";
    };
  };

  home-manager.sharedModules = [
    ({...}: {
      programs.lutris.enable = true;
    })
  ];
}
