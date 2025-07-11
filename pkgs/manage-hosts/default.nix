{
  writeShellApplication,
  nushell,
  openssh,
  sops,
  ssh-to-age,
  age,
  sshpass,
  nixos-anywhere,
  ...
}:
writeShellApplication {
  name = "manage-hosts";

  runtimeInputs = [
    nushell
    openssh
    ssh-to-age
    age
    sops
    sshpass
    nixos-anywhere
  ];

  text = ''
    nu ${./.}/manage-hosts.nu "$@"
  '';
}
