{
  inputs,
  pkgs,
  options,
  hostName,
  lib,
  ...
}: {
  imports = [
    inputs.optnix.nixosModules.optnix
  ];

  # surface options defined by home-manager modules from inputs too
  home-manager.sharedModules = [
    {
      imports = [
        inputs.nvf.homeManagerModules.default
      ];
    }
  ];

  nix.settings = {
    substituters = ["https://watersucks.cachix.org"];
    trusted-public-keys = [
      "watersucks.cachix.org-1:6gadPC5R8iLWQ3EUtfu3GFrVY7X6I4Fwz/ihW25Jbv8="
    ];
  };

  programs.optnix = let
    optnixLib = inputs.optnix.mkLib pkgs;
  in {
    enable = true;
    settings = {
      min_score = 3;
      default_scope = "nix-config";
      formatter_cmd = "${lib.getExe pkgs.alejandra}";
      scopes.nix-config = {
        description = "Options of " + (import ../../flake.nix).description;
        options-list-file = optnixLib.mkOptionsList {inherit options;};
        evaluator = "nix eval ~/repositories/github.com/osipog/nix-config#nixosConfigurations.${hostName}.config.{{ .Option }}";
      };
    };
  };
}
