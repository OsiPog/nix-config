flake: module: {
  config,
  lib,
  hostName,
}: let
  inherit (lib) pipe;

  inherit (flake.lib) nixosHostNames;
in
  {...}: {
    imports =
      map (hostName: ({...}: {
        network.hosts.${hostName}.imports = [module];
      }))
      nixosHostNames;
  }
