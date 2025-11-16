flake: let
  inherit (flake.inputs) nixpkgs;
  inherit (nixpkgs) lib;

  inherit (builtins) attrNames typeOf;
  inherit (lib) pipe;
  inherit (lib.attrsets) listToAttrs mapAttrs;
  # Need to import that manually
  fileTreeAsAttrs = dir: (import ./lib/fileTreeAsAttrs.nix lib) dir;

  importFilesAsAttrs = dir: let
    attrsFiles = fileTreeAsAttrs dir;

    func = mapAttrs (
      _: value:
        if typeOf value == "set"
        then func value
        else import value
    );
  in
    func attrsFiles;

  callAttrs = attrs: arg:
    mapAttrs (_: value:
      if typeOf value == "set"
      then callAttrs value arg
      else value arg)
    attrs;

  systems = attrNames nixpkgs.legacyPackages;
in
  # lib argument
  (callAttrs (importFilesAsAttrs ./lib) lib)
  # flake argument
  // (callAttrs (importFilesAsAttrs ./flake) (flake.flake // {inherit (flake) inputs;}))
  # pkgs argument, do for each system
  // (pipe systems [
    (map (system: {
      name = system;
      value = callAttrs (importFilesAsAttrs ./pkgs) {
        inherit (flake) flake;
        pkgs = nixpkgs.legacyPackages.${system};
      };
    }))
    listToAttrs
  ])
