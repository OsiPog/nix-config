lib: let
  inherit (builtins) throw;
  inherit (lib.lists) unique findFirst;
in
  attr: listOfAttrs: let
    uniqueValues = unique (map (e: e.${attr}) listOfAttrs);
  in
    map (value: findFirst (e: e.${attr} == value) (throw "Will always find it") listOfAttrs) uniqueValues
