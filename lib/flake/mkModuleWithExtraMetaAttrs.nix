flake: {
  mapExtraMetaAttr ? (name: content: {}), # function that evaluates unknown meta attributes, should return null for unexpected meta attr
  extraSpecialArgs ? {}, # extra special args added during module evaluation
}: module: moduleArgs: let
  inherit (builtins) elem attrNames foldl';
  inherit (moduleArgs.lib.attrsets) attrsToList recursiveUpdate;

  evaluated =
    if module != null
    then module (moduleArgs // extraSpecialArgs)
    else {};

  metaAttrs = [
    "imports"
    "options"
    "config"
  ];

  configIsRoot = elem "config" (attrNames evaluated);
in
  if configIsRoot
  then evaluated
  else
    foldl' (
      acc: {
        name,
        value,
      }:
        recursiveUpdate acc (
          if elem name metaAttrs
          then {${name} = value;}
          else let
            mapped = mapExtraMetaAttr name value;
          in
            if mapped != null
            then mapped
            else throw "mkModuleWithExtraMetaAttrs: got unexpected meta attribute name: '${name}'"
        )
    ) {} (attrsToList evaluated)
