lib: let
  inherit (builtins) readDir filter listToAttrs pathExists;
  inherit (lib) pipe;
  inherit (lib.strings) removeSuffix hasSuffix;
  inherit (lib.attrsets) attrsToList;

  importDirectoryRecursive = path:
    pipe path [
      readDir
      attrsToList
      (filter (e: hasSuffix ".nix" e.name || e.value == "directory"))

      (map (file: {
        name = pipe file.name [
          (str:
            if str == "default.nix" && pathExists "${path}.nix"
            then throw "Ambiguous Nix files: both ${path}.nix and ${path}/default.nix exist"
            else str)
          (removeSuffix "default.nix")
          (removeSuffix ".nix")
        ];
        value =
          if file.value == "directory"
          then importDirectoryRecursive "${path}/${file.name}"
          else # by definition of readDir "regular" which describes a normal file, and it will be a nix file (filter above)
            import "${path}/${file.name}";
      }))

      # convert the name value pairs to attrsets
      listToAttrs
    ];
in
  importDirectoryRecursive
