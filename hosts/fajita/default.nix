{
  flake,
  inputs,
  ...
}: {
  class = "robotnix";

  value = inputs.robotnix.lib.robotnixSystem {
    flavor = "lineageos";

    # Supported devices are listed under https://wiki.lineageos.org/devices/
    device = "fajita";

    # LineageOS branch.
    # You can check the supported branches for your device under
    # https://wiki.lineageos.org/devices/fajita/variant1
    # Leave out to choose the official default branch for the device.
    flavorVersion = "22.2";

    apps = {
      fdroid.enable = true;
      seedvault.enable = true;
    };
    microg.enable = true;

    # Enables ccache for the build process. Remember to add /var/cache/ccache as
    # an additional sandbox path to your Nix config.
    ccache.enable = true;

    stateVersion = "3";
  };
}
