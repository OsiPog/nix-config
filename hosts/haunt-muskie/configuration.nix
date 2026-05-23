{
  flake,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = with flake.nixosModules; [
    ./hardware-configuration.nix
    shared

    disko-basic
    headscaleDeclarativePolicy
  ];

  services.headscale.policy.acls = [
    # every user may access internet and their own nodes
    {
      "action" = "accept";
      "src" = ["autogroup:member"];
      "dst" = [
        "autogroup:self:*"
        "autogroup:internet:*"
      ];
    }
    # every user may access the reverse proxy (all ports)
    {
      "action" = "accept";
      "src" = ["autogroup:member"];
      "dst" = ["haunt-muskie:*"];
    }
    # every user may access the dns server (only port 53)
    {
      "action" = "accept";
      "src" = ["autogroup:member"];
      "dst" = ["floating-trees:53"];
    }
  ];

  system.stateVersion = "25.11";
}
