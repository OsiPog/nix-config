{
  pkgs,
  lib,
  config,
  inputs,
  flake,
  ...
}: {
  imports = with inputs; [
    home-manager.nixosModules.default

    (mkUserModule "leaf")
  ];

  # leaf user has a default password
  sops.secrets."pass-hashes/leaf" = {
    neededForUsers = true;
  };
  users.users.leaf = {
    extraGroups = ["wheel"];
    hashedPasswordFile = lib.mkDefault (config.getSopsFile "pass-hashes/leaf");
  };

  # immutable users
  users.mutableUsers = false;

  home-manager = {
    extraSpecialArgs = {
      inherit inputs;
      inherit flake;
    };
    useGlobalPkgs = true;
    backupFileExtension = "backupFileExtension";

    # Home manager settings for every user
    sharedModules = [
      (
        {nixosConfig, ...}: {
          # Let home manager manage itself
          programs.home-manager.enable = true;
          # OpenSSH
          programs.ssh.enable = true;
          # As home manager is installed on each system the same time as home manager the state version is the same
          home.stateVersion = nixosConfig.system.stateVersion;
          programs.fish.enable = true;
        }
      )
    ];
  };

  # Default shell
  users.defaultUserShell = pkgs.fish;
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # disable the greeting
      set fish_greeting
    '';
  };
}
