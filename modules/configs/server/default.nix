{lib, ...}: {
  imports = [
    # Essential stuff
    .././shared/system/essentials.nix
  ];

  # Autologin with user
  services.getty.autologinUser = "user";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = let
    publicSshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIONJE7lYiuiEMPYII3aFk3WBNeNeDN4YCFaKJ6pwYQtA user";
  in {
    root = {
      isNormalUser = false;
      openssh.authorizedKeys.keys = [
        publicSshKey
      ];
    };
    user = {
      isNormalUser = true;
      extraGroups = ["wheel"]; # Enable ‘sudo’ for the user.
      openssh.authorizedKeys.keys = [
        publicSshKey
      ];
    };
  };

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    ports = [22];
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
    };
  };
}
