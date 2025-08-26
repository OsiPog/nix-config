{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "rebuild";

  runtimeInputs = with pkgs; [
    nushell
    git
    nixos-rebuild
  ];

  text = ''
    nu ${./rebuild.nu} "$@"
  '';
}
