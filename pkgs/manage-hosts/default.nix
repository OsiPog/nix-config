{
  writeShellApplication,
  nushell,
  openssh,
  sops,
  ssh-to-age,
  age,
  sshpass,
  nixos-anywhere,
  mustache-go,
  pwgen,
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
    mustache-go
    pwgen
  ];

  text = ''
    nu ${./.}/manage-hosts.nu "$@"
  '';
}
