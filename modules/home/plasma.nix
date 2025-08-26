{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.plasma-manager.homeManagerModules.plasma-manager
  ];

  home.packages = with pkgs; [
    spectacle # screenshot utility
    yakuake # dropdown terminal
  ];

  programs.plasma = {
    enable = true;

    # -- HOTKEYS --
    # custom
    hotkeys.commands = {
      # I don't really use that, I just keep it here in case I forget how it's done.
      # This could be really useful at some point.
      launch-konsole = {
        name = "Launch Konsole";
        key = "Meta+K";
        command = "konsole";
      };
    };
    # kwin
    shortcuts = {
      kwin = {
        "Window Maximize" = "Meta+M";
        "Expose" = "Meta+O";
      };
      "org.kde.spectacle.desktop" = {
        "RectangularRegionScreenShot" = "Meta+Shift+S";
      };
      kcm_touchpad = {
        "Toggle Touchpad" = "Meta+N";
      };
      yakuake = {
        toggle-window-state = "Meta+Y";
      };
    };

    # low level config editing
    configFile = {
      # -- KWIN --
      kwinrc = {
        # Deactivate this because this would falsely activate itself when laptop docked
        Input = {
          "TabletMode" = "off";
        };

        # Configuring two virtual desktops
        Desktops = {
          Number = "2";
        };

        # Mouse should be sticking between screens
        EdgeBarrier = {
          CornerBarrier = "false";
          EdgeBarrier = "0";
        };

        # --- DESKTOP EFFECTS ---

        # When sliding between desktops there should be no gap between
        Effect-slide = {
          HorizontalGap = "0";
        };

        Effect-windowview = {
          # Slide up from touchscreen bottom border to show all windows
          "TouchBorderActivate" = "4";
        };

        Plugins = {
          diminactiveEnabled = "true";
        };
      };

      kwinrulesrc = let
        rules = {
          no-titlebar = {
            Description = "Hide the title bar on all windows";
            noborder = "true";
            noborderrule = "3";
            wmclass = ".*";
            wmclassmatch = "3";
          };
        };
      in
        {
          General = let
            names = builtins.attrNames rules;
          in {
            count = builtins.length names;
            rules = builtins.concatStringsSep "," names;
          };
        }
        // rules;

      # -- SETTINGS --
      # Laptop touchpad settings
      kcminputrc = {
        "Libinput/1739/52856/MSFT0001:00 06CB:CE78 Touchpad" = {
          "ClickMethod" = "2";
          "NaturalScroll" = "true";
          "TapToClick" = "true";
          "DisableWhileTyping" = "true";
        };
        Mouse = {
          # Make sure the default cursor is usedy
          cursorTheme = "default";
        };
      };
      #  x11 version, dont use that
      # "touchpadxlibinputrc"."MSFT0001:00 06CB:CE78 Touchpad" = {
      #   "clickMethodAreas" = {
      #     value = "false";
      #     immutable = true;
      #   };
      #   "clickMethodClickfinger" = {
      #     value = "true";
      #     immutable = true;
      #   };
      #   "naturalScroll" = {
      #     value = "true";
      #     immutable = true;
      #   };
      # };

      # Keyboard settings
      kxbrc = {
        Layout = {
          Use = "true";
          ResetOldOptions = "true";

          # German QWERTY (physical) and US Colemak (emulated)
          LayoutList = "de,us";
          VariantList = ",colemak";

          # Disable CAPS Lock (Who uses that anyway?)
          # Alt+Space to toggle layouts
          Options = "caps:backspace,grp:alt_space_toggle";
        };
      };

      # -- LOOK AND FEEL --
      ksplashrc = {
        KSplash = {
          Engine = "None";
          Theme = "None";
        };
      };

      # -- WIDGETS --
      # make task bar panel 60 wide
      plasmashellrc = {
        "PlasmaViews/Panel 2/Defaults" = {
          thickness = "60";
          immutability = "1";
        };
      };

      "plasma-org.kde.plasma.desktop-appletsrc" = {
        # set nix logo as application menu icon (immutable must be set through "immutability" attribute)
        "Containments/2/Applets/3/Configuration/General" = {
          icon = "nix-snowflake";
          immutability = "1";
        };
        # make task bar a side panel
        "Containments/2" = {
          formfactor = "3";
          location = "5";
          immutability = "1";
        };
        # Task manager
        "Containments/2/Applets/5/Configuration/General" = {
          launchers =
            "applications:firefox.desktop" # Firefox, preferred://browser can have unexpected results when multiple are installed
            + ",applications:chromium-browser.desktop" # Chromium
            + ",applications:codium.desktop" # Codium
            + ",applications:org.kde.konsole.desktop"; # Terminal: konsole
          immutability = "1";
        };
        # Date display
        "Containments/2/Applets/18/Configuration/Appearance" = {
          customDateFormat = "dd.MM.yy";
          dateFormat = "custom";
        };
      };
    };
  };
}
