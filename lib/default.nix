self: let
  inherit (self.inputs) nixpkgs;
  inherit (nixpkgs) lib;

  inherit (builtins) attrNames typeOf;
  inherit (lib) pipe;
  inherit (lib.attrsets) listToAttrs mapAttrs;

  # Need to import that manually
  importFilesAsAttrs = import ./lib/importFilesAsAttrs.nix lib;

  callAttrs = attrs: arg:
    mapAttrs (
      _: value:
        if typeOf value == "set"
        then callAttrs value arg
        else value arg
    )
    attrs;

  systems = attrNames nixpkgs.legacyPackages;
in
  # lib argument
  (callAttrs (importFilesAsAttrs ./lib) lib)
  # flake argument
  // (callAttrs (importFilesAsAttrs ./self) self)
  # pkgs argument, do for each system
  // (pipe systems [
    (map (system: {
      name = system;
      value = callAttrs (importFilesAsAttrs ./pkgs) nixpkgs.legacyPackages.${system};
    }))
    listToAttrs
  ])
