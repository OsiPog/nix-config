{...}: {
  imports = [
    # inputs.determinate.nixosModules.default
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

      # For AOSP building
      sandbox-paths = [
        "/var/cache/ccache"
      ];
    };
    # Automatic garbage collection
    gc = {
      automatic = true;
      dates = "monthly";
      options = "--delete-older-than 14d";
    };

    # checkConfig = false; # to allow setting options below that normal nix can't parse
    extraOptions = ''
      download-buffer-size = 134217728
      # eval-cores = 0
    '';
  };

  # create cache dir from above
  system.activationScripts.mkdir-ccache.text = "mkdir -p /var/cache/ccache";

  documentation = {
    # TODO: remove when works again
    enable = false;
    # Disable generation of man caches
    man.generateCaches = false;
  };
}
