{
  pkgs,
  lib,
  ...
}: let
  # Set of font awesome name and unicode code
  fa-icons = {
    battery-empty = "f244";
    battery-full = "f240";
    battery-half = "f242";
    battery-quarter = "f243";
    battery-three-quarters = "f241";
    bluetooth-b = "f294";
    bolt = "f0e7";
    camera = "f030";
    display = "e163";
    download = "f019";
    ellipsis = "f141";
    expand = "f065";
    keyboard = "f11c";
    laptop = "f109";
    lightbulb = "f0eb";
    moon = "f186";
    mug-hot = "f7b6";
    mug-saucer = "f0f4";
    network-wired = "f6ff";
    upload = "f093";
    volume-high = "f028";
    volume-xmark = "f6a9";
    wifi = "f1eb";
    xmark = "f00d";
  };
  # get html unicode escape sequence for font awesome icon name
  fa = name: "&#x" + fa-icons.${name} + ";";
in {
  imports = [
    ./tools/hypr-toggle-laptop-kb.nix
    ./tools/hypr-rotate-current-screen.nix
    ./tools/matcha.nix
  ];

  # Options for my hypr-toggle-laptop-kb module
  hypr-toggle-laptop-kb = {
    enable = true;
    waybarIntegration = {
      enable = true;
      barName = "bottomBar";
    };
    toggleOnLidSwitch.enable = true;
  };
  # Options for matcha idle inhibitor module
  matcha = {
    enable = true;
    waybarIntegration = {
      enable = true;
      barName = "bottomBar";
    };
  };
  hypr-rotate-current-screen = {
    enable = true;
    waybarIntegration = {
      enable = true;
      barName = "bottomBar";
    };
  };

  # Allow installation of fonts through home.packages
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    # font-awesome # for waybar icons
    font-awesome

    wvkbd # on-screen keyboard
  ];

  wayland.windowManager.hyprland.settings.bind = [
    # Toggle waybar with keyboard combo
    "$meta, Z, exec, pkill waybar || waybar"
    "$meta, grave, exec, pkill waybar || waybar"
  ];

  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";

        # Module placement
        modules-left = [
          "battery"
          "network"
        ];
        modules-center = [
          "clock#time"
          "clock#date"
        ];
        modules-right = [
          "custom/hypr-window-close"
          "hyprland/window"
          "custom/runner"
        ];

        # Module settings
        battery = {
          states = {
            warning = 30;
            critical = 15;
            fatal = 5;
          };

          format = "{icon} {capacity} %";

          # State specific formats
          format-fatal = (fa "battery-empty") + "! {capacity} %";

          # Status specific formats
          format-charging = (fa "bolt") + " {icon} {capacity} %";

          format-icons = map fa [
            "battery-quarter"
            "battery-half"
            "battery-three-quarters"
            "battery-full"
          ];

          interval = 2;
        };

        "clock#time" = {
          format = "{:%H:%M}";
        };
        "clock#date" = {
          format = "{:%A, %d. %B %Y}";
        };

        "network" = {
          format-ethernet = fa "network-wired";
          format-wifi = (fa "wifi") + " {essid}";
          tooltip-format = ''${fa "download"} {bandwidthDownBits}  ${fa "upload"} {bandwidthUpBits}'';
        };

        "hyprland/window" = {
          format = "{class}";
          icon = true;
          icon-size = 18;
          seperate-outputs = true;
          rewrite = {
            # sometimes window classes formed like: com.github.xournalpp.xournalpp
            # this regex shows only the last string
            "^(?:.+?\\.)+(.+)$" = "$1";
          };
          on-click = pkgs.writeShellScript "" ''
            hyprctl dispatch fullscreen 1
          '';
        };
        "custom/hypr-window-close" = {
          format = fa "xmark";
          on-click = pkgs.writeShellScript "" ''
            hyprctl dispatch killactive
          '';
        };

        "custom/runner" = {
          format = fa "ellipsis";
          on-click = pkgs.writeShellScript "" ''
            pkill wofi || wofi --show drun
          '';
        };
      };
      bottomBar = {
        layer = "top";
        position = "bottom";

        modules-left = [
          "pulseaudio"
          "pulseaudio/slider"
          "backlight"
          "backlight/slider"
        ];

        modules-right = [
          "custom/hypr-rotate-current-screen"
          "custom/hypr-toggle-laptop-kb"
          "custom/matcha"
          "custom/hyprshot"
          "custom/wvkbd-mobintl"
        ];

        "backlight" = {
          format = fa "lightbulb";
        };
        "backlight/slider" = {
          min = 2;
        };

        "pulseaudio" = {
          format = fa "volume-high";
          format-bluetooth = (fa "bluetooth-b") + " " + (fa "volume-high");
        };

        "custom/wvkbd-mobintl" = {
          format = fa "keyboard";
          on-click = pkgs.writeShellScript "" ''
            pkill wvkbd-mobintl || wvkbd-mobintl -H 300 -L 300
          '';
        };

        "custom/hyprshot" = {
          format = (fa "display") + " " + (fa "camera");
          on-click = pkgs.writeShellScript "" ''
            pkill hyprshot || hyprshot -m region --clipboard-only --freeze
          '';
        };
      };
    };
  };
}
