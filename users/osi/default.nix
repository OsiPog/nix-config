{
  self,
  inputs,
  pkgs,
  ...
}: let
  inherit (self.lib) mkUserModule;

  username = "osi";
in {
  imports = with self.nixosModules;
  with inputs.nix-config-private.nixosModules; [
    theme-prismarine

    # private
    uni-vpn

    (mkUserModule username)
  ];

  programs.hyprland.enable = true;
  
  services.desktopManager.plasma6.enable = true;

  # Enable sudo for user
  users.users.${username}.extraGroups = ["wheel"];

  services.greetd.settings = {
    # Run hyprland on boot (autologin)
    initial_session = {
      command = "Hyprland";
      user = username;
    };
  };

  # Home Manager configuration
  home-manager.users.${username} = import ./home.nix;
}
