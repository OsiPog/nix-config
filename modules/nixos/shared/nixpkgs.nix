{
  inputs,
  lib,
  ...
}: {
  nixpkgs.overlays = with inputs; [
    # Add packages of the flakes in an overlay
    (
      final: prev: let
        stable = nixpkgs-stable.legacyPackages.${prev.system};
      in {
        # to access stable packages
        inherit stable;

        # custom flake packages
        matcha = matcha.packages.${prev.system}.default;
        self = outputsEachSystem.packages.${prev.system};
      }
    )
  ];
}
