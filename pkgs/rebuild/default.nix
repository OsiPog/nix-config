{
  writeShellApplication,
  nushell,
  git,
  nixos-rebuild,
  ...
}:
writeShellApplication {
  name = "rebuild";

  runtimeInputs = [
    nushell
    git
    nixos-rebuild
  ];

  text = ''
    nu ${./rebuild.nu} "$@"
  '';
}
