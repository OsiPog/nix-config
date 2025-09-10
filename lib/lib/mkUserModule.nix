_: username: {...}: {
  # Basic user normal user creation
  users.users.${username} = {
    createHome = true;
    isNormalUser = true;
    useDefaultShell = true;
  };
}
