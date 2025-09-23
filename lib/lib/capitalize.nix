lib: let
  inherit (builtins) head tail;
  inherit (lib) pipe;
  inherit (lib.strings) stringToCharacters toUpper concatStrings;
in
  str:
    pipe str [
      stringToCharacters
      (strs:
        if strs == []
        then [""]
        else strs)
      (cs: [(toUpper (head cs))] ++ (tail cs))
      concatStrings
    ]
