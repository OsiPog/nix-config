{
  lib,
  ...
}: let
  inherit (lib) mkDefault;
  inherit (lib.attrsets) mapAttrs;
in {
  i18n = {
    defaultLocale = mkDefault "en_US.UTF-8";
    # Home sweet home german formats
    extraLocaleSettings = mapAttrs (_: mkDefault) {
      LC_ADDRESS = "de_DE.UTF-8";
      LC_IDENTIFICATION = "de_DE.UTF-8";
      LC_MEASUREMENT = "de_DE.UTF-8";
      LC_MONETARY = "de_DE.UTF-8";
      LC_NAME = "de_DE.UTF-8";
      LC_NUMERIC = "de_DE.UTF-8";
      LC_PAPER = "de_DE.UTF-8";
      LC_TELEPHONE = "de_DE.UTF-8";
      LC_TIME = "de_DE.UTF-8";
    };
  };
  time.timeZone = mkDefault "Europe/Berlin";
  services.xserver = {
    xkb.layout = "us,de";
    xkb.variant = "colemak,";
    xkb.options = "grp:win_space_toggle";
  };
  console.keyMap = "colemak";
}