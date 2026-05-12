lib: let
  inherit (builtins) mapAttrs;
  inherit (lib) mkMerge;
  inherit (lib.attrsets) foldAttrs getAttrs genAttrs;
in
  names: attrsList:
    getAttrs names ((genAttrs names (_: {})) // ((mapAttrs (_: mkMerge)) ((foldAttrs (value: acc: [value] ++ acc) []) attrsList)))
