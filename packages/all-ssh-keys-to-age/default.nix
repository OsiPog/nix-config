{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "all-ssh-keys-to-age";

  runtimeInputs = with pkgs; [
    bash
    nushell
    openssh
    ssh-to-age
  ];

  text = ''
    nu ${./all-ssh-keys-to-age.nu} "$@"
  '';
}
