{
  lib,
  callPackage,
  ...
} @ pkgs: let
  inherit (builtins) readDir listToAttrs filter;
  inherit (lib) pipe;
  inherit (lib.strings) hasSuffix removeSuffix;
  inherit (lib.attrsets) attrsToList;
in
  path:
    pipe path [
      readDir
      attrsToList
      (filter (e: hasSuffix ".nix" e.name || e.value == "directory"))
      (map (file: {
        name = removeSuffix ".nix" file.name;
        value = callPackage "${path}/${file.name}" pkgs;
      }))
      listToAttrs
    ]
