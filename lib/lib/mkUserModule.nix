lib:
let
in
username:
{ ... }:
{
  # Basic user normal user creation
  users.users.${username} = {
    createHome = true;
    home = "/home/${username}";
    isNormalUser = true;
    useDefaultShell = true;
  };
}
