{inputs, ...}: {
  imports = [
    inputs.determinate.nixosModules.default
  ];

  nix = {
    settings = {
      # enable flakes and nix command
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [
        # devenv
        "https://devenv.cachix.org"
        # determinate systems
        "https://install.determinate.systems"
      ];

      trusted-public-keys = [
        # devenv
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        # determinate systems
        "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      ];
    };
    # Automatic garbage collection
    gc = {
      automatic = true;
      dates = "monthly";
      options = "--delete-older-than 30d";
    };

    extraOptions = ''
      download-buffer-size = 134217728
      eval-cores = 0
    '';
  };

  # Disable generation of man caches
  documentation.man.generateCaches = false;
}
