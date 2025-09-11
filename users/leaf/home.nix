{
  flake,
  lib,
  inputs,
  ...
}:
{
  home = rec {
    username = "leaf";
    homeDirectory = "/home/${username}";
    stateVersion = lib.mkDefault "25.11";
  };
}
