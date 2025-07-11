{
  self,
  lib,
  inputs,
  ...
}: {
  home = rec {
    username = "osi";
    homeDirectory = "/home/${username}";
    stateVersion = lib.mkDefault "25.11";
  };

  imports = with self.homeManagerModules;
  with inputs.nix-config-private.homeManagerModules; [
    # shell
    fish
    git

    # terminal
    kitty

    # Window manager
    hyprland # base config
    hyprland-laptop # for laptops
    hyprland-touch # for laptops
    hyprland-waybar # utility bar
    hyprland-lockscreen # lockscreen with auto enable on inactivity
    hyprland-runner
    hyprland-workspaces

    # code editor
    vscode
    nvf

    # web browser
    firefox
    chromium # when firefox fails

    # password manager
    password-store

    # Some common desktop apps I need
    desktop-apps
    cli-tools

    # syncing files
    syncthing

    # private
    uni
  ];

  programs.gpg.publicKeys = [
    {
      trust = 5;
      source = ./0x675D2CB5013E8731.pub;
    }
  ];
}
