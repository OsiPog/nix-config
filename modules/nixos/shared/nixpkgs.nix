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
    hostPlatform = lib.mkOptionDefault "x86_64-linux";
    overlays = with inputs; [
      # Add packages of the flakes in an overlay
      (
        final: prev:
          recursiveUpdate prev {
            # to access stable packages
            inherit stable;

            # hyprlandPlugins.hyprgrass = prev.hyprlandPlugins.hyprgrass.overrideAttrs (prevAttrs: {
            #   src = prev.fetchFromGitHub {
            #     owner = "horriblename";
            #     repo = "hyprgrass";
            #     rev = "668d2e44a647a302047adbb72bf3649dc8f1f1d7";
            #     hash = "sha256-KgroQaxZBjT/iaoNdbWN2N7rMfAOTrDeJMml5FFdfrk=";
            #   };
            # });

            hyprlandPlugins.hyprgrass = stable.hyprlandPlugins.hyprgrass;

            # hyprland = prev.hyprland.overrideAttrs (prevAttrs: {
            #   src = prev.fetchFromGitHub {
            #     owner = "hyprwm";
            #     repo = "hyprland";
            #     rev = "";
            #     hash = "sha256-OFTMhMUnJCg3woctP+qrWNM0ALeiTnGlbsC7eHStdDY=";
            #   };
            # });

            # custom flake packages
            matcha = matcha.packages.${prev.system}.default;
            self = outputsEachSystem.packages.${prev.system};
          }
      )
    ];
  };
}
