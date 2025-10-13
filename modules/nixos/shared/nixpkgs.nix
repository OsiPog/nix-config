{
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.attrsets) recursiveUpdate;

  stable = inputs.nixpkgs-stable.legacyPackages.${pkgs.system};
in {
  nixpkgs = {
    hostPlatform = lib.mkDefault "x86_64-linux";
    overlays = with inputs; [
      # Add packages of the flakes in an overlay
      (
        final: prev:
          recursiveUpdate prev {
            # to access stable packages
            inherit stable;

            hyprlandPlugins.hyprgrass = prev.hyprlandPlugins.hyprgrass.overrideAttrs (prevAttrs: {
              src = prev.fetchFromGitHub {
                owner = "horriblename";
                repo = "hyprgrass";
                rev = "9b341353a91c23ced96e5ed996dda62fbe426a32";
                hash = "sha256-Nwd8JwGEEdGBJthxiopK51Fwva5TbM1PEOQDe+NAZEw=";
              };
            });

            # custom flake packages
            matcha = matcha.packages.${prev.system}.default;
            self = outputsEachSystem.packages.${prev.system};
          }
      )
    ];
  };
}
