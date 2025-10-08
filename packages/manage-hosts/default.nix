{pkgs, ...}:
pkgs.writeShellApplication {
  name = "manage-hosts";

  runtimeInputs = with pkgs; [
    nushell
    openssh
    ssh-to-age
    age
    sops
    sshpass
    nixos-anywhere
    mustache-go
    pwgen
    nixos-facter
    lazygit
  ];

  text = ''
    nu ${./.}/manage-hosts.nu "$@"
  '';
}
