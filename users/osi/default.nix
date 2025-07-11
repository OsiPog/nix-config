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
    greetd-hyprland

    # private
    uni-vpn

    (mkUserModule username)
  ];

  # Enable sudo for user
  users.users.${username}.extraGroups = ["wheel"];

  services.greetd.settings = {
    # Run hyprland on boot (autologin)
    initial_session = {
      command = "${pkgs.hyprland}/bin/Hyprland";
      user = username;
    };
  };

  # Home Manager configuration
  home-manager.users.${username} = import ./home.nix;
}
