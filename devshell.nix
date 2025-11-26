{
  pkgs,
  perSystem,
  ...
}:
pkgs.mkShell {
  name = (import ./flake.nix).description;
  packages = with perSystem.self;
  with perSystem.nix-minecraft; [
    # my custom host manager
    manage-hosts
    # tool to prefetch minecraft things from modrinth
    nix-modrinth-prefetch
  ];

  shellHook = ''
    git status
  '';
}
