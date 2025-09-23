lib: let
  inherit (builtins) head tail;
  inherit (lib) pipe;
  inherit (lib.lists) flatten;
  inherit (lib.strings) splitString concatStrings;

  capitalize = import ./capitalize.nix lib;
in
  str:
    pipe str [
      # Split by all known seperators
      (splitString "-")
      (map (splitString "_"))
      flatten
      (map (splitString " "))
      flatten
      # capitalize each except first
      (strs: [(head strs)] ++ (map capitalize (tail strs)))

      concatStrings
    ]
