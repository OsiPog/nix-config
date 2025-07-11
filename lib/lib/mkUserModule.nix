lib: let
in
  username: {config, ...}: {
    sops.secrets."pass-hashes/${username}" = {neededForUsers = true;};

    # Basic user normal user creation
    users.users.${username} = {
      createHome = true;
      hashedPasswordFile = config.getSopsFile "pass-hashes/${username}";
      home = "/home/${username}";
      isNormalUser = true;
      useDefaultShell = true;
    };
  }
