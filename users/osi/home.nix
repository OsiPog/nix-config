{
  flake,
  lib,
  inputs,
  ...
}: {
  home = rec {
    username = "osi";
    homeDirectory = "/home/${username}";
    stateVersion = lib.mkDefault "25.11";
  };

  imports = with flake.homeModules;
  with inputs.nix-config-private.homeModules; [
    # shell
    fish
    git

    # terminal
    kitty

    # Window manager
    hyprland # base config
    hypr-laptop # for laptops
    hypr-touch # for laptops
    waybar # utility bar
    hypr-lockscreen # lockscreen with auto enable on inactivity
    hypr-runner
    hypr-workspaces

    # code editor
    vscode
    # nvf
    helix

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
    work
  ];

  programs.gpg.publicKeys = [
    {
      trust = 5;
      source = ./0x675D2CB5013E8731.pub;
    }
  ];
}
