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
    # vdfplus
    vdfplus
    # generate PostgreSQL SCRAM-SHA-256 password hashes
    pg-scram-sha256
  ];

  shellHook = ''
    git status
  '';
}
