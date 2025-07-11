{
  pkgs,
  nixosConfig,
  config,
  lib,
  ...
}: let
  themeCfg = nixosConfig.prismarineTheme;
in {
  # Hyprland itself
  wayland.windowManager.hyprland = {
    plugins = with pkgs.hyprlandPlugins; [
      # hyprfocus # currently broken in nixpkgs
    ];

    settings = {
      # --- General ---
      general = {
        border_size = themeCfg.border-width;
        gaps_out = themeCfg.margin;
        gaps_in = themeCfg.margin;
      };

      misc = {
        disable_hyprland_logo = true; # hyprpaper is already running
        disable_splash_rendering = true; # not visible due to hyprpaper
      };

      decoration = {
        rounding = themeCfg.border-radius;

        blur = {
          enabled = true;
        };
      };

      cursor = {
        hide_on_key_press = true;
        inactive_timeout = 1;
        no_hardware_cursors = true;
      };

      # --- Animations ---
      bezier = [
        "fast-in, 0.34, 0.12, 0.07, 0.96"
      ];
      animation = [
        "windows, 1, 3, fast-in, popin"
        "layers, 1, 3, fast-in"
      ];

      # --- Layerrules and Window Rules
      layerrule = [
        "animation popin, (w|r)ofi"
        # "dimaround, (w|r)ofi"
        "abovelock true, waybar"
        "abovelock true, wvkbd"
      ];
      windowrule = [
        "pin, class:(w|r)ofi"
        # "stayfocused, class:(w|r)ofi" # cant click outside
        # "dimaround, class:(w|r)ofi"
      ];

      # --- Plugins ---
      plugin = {
        # --- Hyprfocus, flash aniomation on focus change
        # hyprfocus = {
        #   enabled = "yes";
        #   focus_animation = "flash";
        #   flash = {
        #     flash_opacity = 0.8;
        #   };
        # };
      };
    };
  };
}
