lib: let
  inherit (builtins) attrNames head;
in
  attrs: attrs.${head (attrNames attrs)}
