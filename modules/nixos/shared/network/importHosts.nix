_module @ {
  flake,
  lib,
  ...
}: let
  inherit (builtins) attrNames readDir pathExists;
  inherit (lib.attrsets) genAttrs;

  hostNames = attrNames (readDir ../../../../hosts);
in {
  network = {
    # populate network.hosts.<name> with the respective host config in hosts/<name>/network.nix
    hosts = genAttrs hostNames (
      hostName: let
        hostConfigFile = "${flake}/hosts/${hostName}/network.nix";
      in
        if (pathExists hostConfigFile)
        then (import hostConfigFile _module)
        else {}
    );
  };
}
