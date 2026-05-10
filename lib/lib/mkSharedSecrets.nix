lib: names: sopsFile:
lib.genAttrs names (name: {
  inherit sopsFile;
  group = builtins.replaceStrings ["/"] ["_"] name;
  mode = "0440";
})
