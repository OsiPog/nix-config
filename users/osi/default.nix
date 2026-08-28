{
  flake,
  inputs,
  config,
  pkgs,
  ...
}: let
  inherit (flake.lib) mkUserModule;

  username = "osi";
in {
  imports = with flake.nixosModules; [
    theme-prismarine

    uni-vpn
    llm-tools

    (mkUserModule username)
  ];

  sops.secrets."pass-hashes/osi" = {
    neededForUsers = true;
    sopsFile = ./secrets.yaml;
  };

  programs.hyprland.enable = true;

  users.extraGroups.podman.members = [username];
  users.extraGroups.dialout.members = [username];
  users.extraGroups.cdrom.members = [username];

  users.users.${username} = {
    # Enable sudo for user
    extraGroups = [
      "wheel" # really important, allows sudo
      "adbusers"
      "ydotool"
    ];
    # password
    hashedPasswordFile = config.getSopsFile "pass-hashes/osi";
  };
  # Allow the user to use the host ssh key
  system.activationScripts."copy-host-key-to-${username}".text = ''
    cp /etc/ssh/id_ed25519 /home/${username}/.ssh/id_ed25519
    chown ${username} /home/${username}/.ssh/id_ed25519
    rm --force /home/${username}/id_ed25519.pub
  '';

  services.greetd.settings = {
    # Run hyprland on boot (autologin)
    initial_session = {
      command = "start-hyprland";
      user = username;
    };
  };

  environment.systemPackages = with pkgs; [
    zotero
    k2pdfopt
  ];

  # Home Manager configuration
  home-manager.users.${username} = import ./home.nix;
}
