{...}: {
  nix = {
    # enable flakes and nix command
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Automatic garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    # Allow cachix to provide caches
    extraOptions = ''
      extra-substituters = https://devenv.cachix.org
      extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=

      download-buffer-size = 134217728
    '';
  };

  # Disable generation of man caches
  documentation.man.generateCaches = false;
}
