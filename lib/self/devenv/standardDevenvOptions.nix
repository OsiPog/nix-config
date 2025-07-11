self: let
  devenvFlake = self.inputs.devenv;
in
  # This is copied and adapted from:
  # https://github.com/cachix/devenv/blob/3febc91939aea65bdff8850f026443afb6b6b22f/flake.nix#L95
  (self.inputs.nixpkgs.lib.evalModules {
    modules = [
      (devenvFlake.outPath + "/src/modules/top-level.nix")
    ];
    specialArgs = {
      pkgs = import (devenvFlake.inputs.nixpkgs) {};
      inputs = devenvFlake.inputs;
    };
  }).options
