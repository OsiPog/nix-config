{ ... }:
{
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
  };

  # Disable generation of man caches
  documentation.man.generateCaches = false;
}
