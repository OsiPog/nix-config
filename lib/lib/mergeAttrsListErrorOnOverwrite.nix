lib: attrsList: let
  inherit (builtins) foldl' attrNames typeOf;
  inherit (lib.lists) intersectLists;
  inherit (lib.attrsets) genAttrs;

  mergeAttrsWithErrorOnOverwrite = left: right: prefix: let
    fullAttrName = name:
      if prefix == ""
      then name
      else prefix + "." + name;
    sharedAttrNames = intersectLists (attrNames left) (attrNames right);
  in
    (removeAttrs left sharedAttrNames)
    // (removeAttrs right sharedAttrNames)
    // (
      genAttrs sharedAttrNames (
        name:
        # throw an error if both are not the same type, or when both are different values of the same type (not set, that is handled below)
          if (typeOf left.${name} != typeOf right.${name}) || ((typeOf left.${name} != "set") && left.${name} != right.${name})
          then throw "Cannot merge ${fullAttrName name}: left: ${toString left}, right: ${toString right}"
          else if typeOf left.${name} == "set" # both are of type set
          then mergeAttrsWithErrorOnOverwrite left.${name} right.${name} (fullAttrName name)
          # wont happen, all cases handled above
          else {}
      )
    );
in
  foldl' (acc: e: mergeAttrsWithErrorOnOverwrite acc e "") {} attrsList
