{
  writeShellApplication,
  nushell,
  openssh,
  ssh-to-age,
  bash,
  ...
}:
writeShellApplication {
  name = "all-ssh-keys-to-age";

  runtimeInputs = [
    nushell
    openssh
    ssh-to-age
    bash
  ];

  text = ''
    nu ${./all-ssh-keys-to-age.nu} "$@"
  '';
}
