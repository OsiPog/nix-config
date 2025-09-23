{
  flake,
  inputs,
  lib,
  config,
  ...
}: let
  inherit (flake.lib) mkUserModule;

  username = "leaf";
in {
  imports = with flake.nixosModules; [
    (mkUserModule username)
  ];

  users.users.${username} = {
    # Enable sudo for user (wheel group)
    extraGroups = ["wheel"];
    # Inherit authorized keys from root user
    openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;

    # Use the same password hash as root user
    hashedPasswordFile = config.users.users.root.hashedPasswordFile;
  };

  # Home Manager configuration
  home-manager.users.${username} = import ./home.nix;
}
