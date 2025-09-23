{
  nixosConfig,
  lib,
  config,
  ...
}: let
  themeCfg = nixosConfig.prismarineTheme;
  colors = config.lib.stylix.colors;
in {
  programs.hyprlock.settings = lib.mkIf config.programs.hyprlock.enable {
    general = {
      hide_cursor = true;
    };
    background = {
      monitor = ""; # every monitor
      path = lib.mkForce "screenshot";
      blur_passes = 4;
      blur_size = 10;
    };
    input-field = {
      monitor = "";

      outline_thickness = themeCfg.border-width;
      rounding = themeCfg.border-radius;

      check_color = lib.mkForce "rgb(${colors.base0D})";

      fade_on_empty = true;

      placeholder_text = "";
      fail_text = "";

      fail_timeout = 500;
    };
  };
}
