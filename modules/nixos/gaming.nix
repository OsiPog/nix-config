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
    gamescope-session # comes from jovian-nixos 
  ];

  nixpkgs.config.allowUnfree = true;

  jovian = {
    steam = {
      enable = true;
    };
  };

  home-manager.sharedModules = [({...}: {
    programs.lutris.enable = true;
  })];
}
