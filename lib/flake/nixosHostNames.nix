# Returns a list of all host names (directory names in hosts/) that contain a configuration.nix file
flake: let
  inherit (builtins) attrNames readDir pathExists filter;
  inherit (flake.inputs.nixpkgs.lib) pipe;

  hostsPath = "${flake}/hosts";
in
  pipe hostsPath [
    readDir
    attrNames
    (filter (hostName: pathExists "${hostsPath}/${hostName}/configuration.nix"))
  ]
