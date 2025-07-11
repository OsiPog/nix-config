{
  config,
  lib,
  nixosConfig,
  ...
}: let
  # Defined by stylix somewhere else
  fonts = config.stylix.fonts;
  colors = config.lib.stylix.colors;
  opacity = config.stylix.opacity;

  # Some functions
  str = builtins.toString; # need that a lot
  # Function that takes a base16 color id (like 0A) and outputs a string with rgb values (like "129,89,199)
  rgbString = colorID:
    builtins.concatStringsSep ","
    (map (x: config.lib.stylix.colors."${colorID}-${x}") ["rgb-r" "rgb-g" "rgb-b"]);

  filterStr = str: cs: builtins.concatStringsSep "" (lib.filter (c: ! builtins.elem c cs) (lib.splitString "" str));

  # theme options
  themeCfg = nixosConfig.prismarineTheme;
  border = {
    radius = themeCfg.border-radius;
    width = themeCfg.border-width;
  };
  margin = themeCfg.margin;
  terminal-padding = themeCfg.padding;
in {
  stylix.targets.waybar.enable = false; # turn off stylix ricing that style.css can be changed
  programs.waybar = lib.mkIf config.programs.waybar.enable {
    style = with colors.withHashtag; ''
      /* STYLIX COLORS */
      @define-color base00 ${base00}; @define-color base01 ${base01}; @define-color base02 ${base02}; @define-color base03 ${base03};
      @define-color base04 ${base04}; @define-color base05 ${base05}; @define-color base06 ${base06}; @define-color base07 ${base07};

      @define-color base08 ${base08}; @define-color base09 ${base09}; @define-color base0A ${base0A}; @define-color base0B ${base0B};
      @define-color base0C ${base0C}; @define-color base0D ${base0D}; @define-color base0E ${base0E}; @define-color base0F ${base0F};


      /* FONT SETTINGS */
      * {
        /* `otf-font-awesome` is required to be installed for icons */
        font-family: "${fonts.monospace.name}";
        font-weight: 500;
        font-size: ${str (fonts.sizes.terminal * 0.8)}pt;
      }


      window#waybar {
        /* transparent background */
        background-color: rgba(0, 0, 0, 0);
      }

      .modules-left, .modules-center, .modules-right {
        padding-top: ${str margin}px;
      }
      .modules-left {
        padding-left: ${str margin}px;
      }
      .modules-right {
        padding-right: ${str margin}px;
      }


      /* BASE STYLE OF MODULES */
      .module {
        border-style: solid;
        border-width: ${str border.width}px;
        border-radius: ${str border.radius}px;
        border-color: @base03;

        margin-left: ${str margin}px;
        margin-right: ${str margin}px;

        padding-left: ${str terminal-padding}px;
        padding-right: ${str terminal-padding}px;
        padding-top: ${str (terminal-padding * 0.7)}px;
        padding-bottom: ${str (terminal-padding * 0.4)}px;

        background-color: rgba(${rgbString "base00"}, ${str (opacity.terminal * 0.9)});

        color: @base05;

        transition: all 0.3s ease;
      }

      .module:hover {
        border-color: @base0D;
        background-color: rgba(${rgbString "base00"}, ${str (opacity.terminal * 0.9)});
      }

      /* SHORT BORDER CHANGE ON UPDATE */
      /*
      currently disabled
      ${builtins.concatStringsSep "\n" (
        map (selector: let
          animationName = "notifyChange" + (filterStr selector ["#" "."]);

          defaultStyle = ''
            border-color: @base03;
            min-width: 2rem;
          '';

          emphasizedStyle = ''
            background-color: rgba(${rgbString "base00"}, ${str opacity.terminal});
            border-color: @base0D;
            min-width: 10rem;
          '';
        in ''
          @keyframes ${animationName} {
            0% {
              ${defaultStyle}
            }
            20% {
              ${emphasizedStyle}
            }
            80% {
              ${emphasizedStyle}
            }
            100% {
              ${defaultStyle}
            }
          }
          ${selector} {
            animation: ${animationName} 2s ease;
            animation-play-state: running;
          }
        '') [
          "#battery.charging"
          "#battery.not_charging"
          "#battery.discharging"
        ]
      )}
      */

      /* SLIDERS */
      #pulseaudio-slider, #backlight-slider  {
        min-width: 10rem;
        min-height: 1rem;
        padding-bottom: 0.2rem;
        padding-right: 0.8rem;
        padding-left: 0.8rem;
      }
      slider {
        min-height: 0.5rem;
        min-width: 0.5rem;
      }

      /* HIDE MODULES IN CERTAIN STATES */
        /* Battery is full and plugged in */
        #battery:not(.charging):not(.discharging),
        #backlight.maximum,

        /* No window is focused (hyprland) */
        #waybar.empty #window
      {
        transition: all 0.3s ease;
        opacity: 0;
        margin: 0;
        padding: 0;
        border-width: 0;
        font-size: 0;
      }

      /* BATTERY */
      #battery.warning {
        color: @base0A;
      }
      #battery.critical {
        color: @base09;
      }
      #battery.fatal {
        color: @base08;
      }
    '';
  };
}
