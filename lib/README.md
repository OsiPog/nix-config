# Lib

Here are all utility Nix expressions stored that are used all over the flake. To keep it simple the expressions are automatically imported and available as a flake output. As different functions will have different dependencies (some need nixpkgs, some only need nixpkgs.lib and some other need the whole flake) this dependency discrepancy is represented in the directory structure:

- `lib/pkgs` - Nix expressions that need the entirety of nixpkgs
- `lib/lib` - Nix expressions that only need `pkgs.lib`
- `lib/self` - Nix expressions that need the whole flake as the function argument