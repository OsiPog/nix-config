{
  pkgs,
  flake,
  ...
}:
pkgs.mkShell {
  name = (import ./flake.nix).description;
  packages = builtins.attrValues flake.packages.${pkgs.system};
}
