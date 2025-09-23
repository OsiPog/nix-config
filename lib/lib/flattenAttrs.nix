lib: let
  inherit (builtins) typeOf;
  inherit (lib) pipe;
  inherit (lib.attrsets) attrsToList listToAttrs;
  inherit (lib.lists) flatten;

  toCamelCase = import ./toCamelCase.nix lib;

  flattenAttrs = namePrefix: attrs:
    pipe attrs [
      attrsToList
      (map (
        {
          name,
          value,
        }: let
          newPrefix = (
            if namePrefix == ""
            then name
            else if name == ""
            then namePrefix
            else (namePrefix + "-" + name)
          );
        in
          if typeOf value == "set"
          then attrsToList (flattenAttrs newPrefix value)
          else {
            inherit value;
            name = newPrefix;
          }
      ))
      # flatten every element
      flatten

      listToAttrs
    ];
in
  flattenAttrs ""
