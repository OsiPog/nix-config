lib: let
  inherit (builtins) mapAttrs;
  inherit (lib) mkMerge;
  inherit (lib.attrsets) foldAttrs getAttrs;
in
  names: attrsList:
    getAttrs names ((mapAttrs (_: mkMerge)) ((foldAttrs (value: acc: [value] ++ acc) []) attrsList))
