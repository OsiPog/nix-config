{
  self,
  inputs,
  config,
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

  sops.secrets."pass-hashes/osi" = {neededForUsers = true;};

  programs.hyprland.enable = true;

  users.users.${username} = {
    # Enable sudo for user
    extraGroups = ["wheel"];
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
      command = "Hyprland";
      user = username;
    };
  };

  # Home Manager configuration
  home-manager.users.${username} = import ./home.nix;
}
