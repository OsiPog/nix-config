{...}: {
  boot.kernelModules = ["pcspkr"];

  nixpkgs.overlays = [
    (final: prev: {
      kmod-blacklist-ubuntu = prev.kmod-blacklist-ubuntu.overrideAttrs (old: {
        patches = [
          ./Dont-blacklist-pcspkr.patch
        ];
      });
    })
  ];
}
