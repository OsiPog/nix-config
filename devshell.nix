{
  pkgs,
  perSystem,
  ...
}:
pkgs.mkShell {
  name = (import ./flake.nix).description;
  packages = with perSystem.self.packages;
  with perSystem.nix-minecraft.packages; [
    # my custom host manager
    manage-hosts
    # tool to prefetch minecraft things from modrinth
    nix-modrinth-prefetch
  ];

  shellHook = ''
    git status
  '';
}
