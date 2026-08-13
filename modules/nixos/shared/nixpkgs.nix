{
  inputs,
  lib,
  config,
  ...
}: let
  inherit (builtins) warn;
  inherit (lib) getName;
  inherit (lib.attrsets) recursiveUpdate;
in {
  nixpkgs = {
    config.allowUnfreePredicate = pkg: warn "Unfree package: ${getName pkg}" true;
    hostPlatform = lib.mkOptionDefault "x86_64-linux";
    overlays = [
      inputs.nix-vscode-extensions.overlays.default
      inputs.nix-firefox-addons.overlays.default
      # Add packages of the flakes in an overlay
      (
        final: prev:
          with inputs; let
            stable = import inputs.nixpkgs-stable {
              inherit (prev) system;
              inherit (config.nixpkgs) config;
            };
          in
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
