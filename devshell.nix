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
    # convert current monitor configuration to conf options
    get-hypr-monitors-conf
  ];

  shellHook = ''
    git status
  '';
}
