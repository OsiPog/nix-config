{
  flake,
  lib,
  ...
}: let
  inherit (builtins) pathExists;
  inherit (lib.attrsets) genAttrs;
in {
  network = {
    # populate network.hosts.<name> with the respective host config in hosts/<name>/network.nix
    hosts = genAttrs flake.lib.nixosHostNames (
      hostName: let
        hostConfigFile = "${flake}/hosts/${hostName}/network.nix";
      in
        if (pathExists hostConfigFile)
        then (import hostConfigFile)
        else {}
    );
  };
}
