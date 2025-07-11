{
  runCommand,
  yq,
  lib,
  ...
}: let
  inherit (builtins) fromJSON readFile;
  inherit (lib) pipe;
in
  yaml:
    pipe yaml [
      # convert to json file
      (yaml: runCommand "from-yaml-to-json" {} "echo -e '${yaml}' | ${yq}/bin/yq . > $out")
      readFile # read the file
      fromJSON # and json -> nix attrset
    ]
