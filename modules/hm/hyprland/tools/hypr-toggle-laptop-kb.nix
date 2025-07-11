{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.hypr-toggle-laptop-kb;

  statusFilePath = ''"$XDG_RUNTIME_DIR/keyboard.status"'';

  isEnabled = pkgs.writeShellApplication {
    name = "hypr-toggle-laptop-kb-check";
    text = ''
      if ! [ -f ${statusFilePath} ]; then
        exit 0
      elif [ """$(cat ${statusFilePath})""" = "true" ]; then
        exit 0
      elif [ """$(cat ${statusFilePath})""" = "false" ]; then
        exit 1
      else
        exit 1
      fi
    '';
  };
  toggleKB = pkgs.writeShellApplication {
    name = "hypr-toggle-laptop-kb";
    text = ''
      enable_keyboard() {
          echo "true" >${statusFilePath}
          # notify-send -u normal "Enabling Keyboard"
          hyprctl keyword "\$LAPTOP_KB_ENABLED" "true" -r
      }

      disable_keyboard() {
          echo "false" >${statusFilePath}
          # notify-send -u normal "Disabling Keyboard"
          hyprctl keyword "\$LAPTOP_KB_ENABLED" "false" -r
      }

      if ! ${lib.getExe isEnabled}; then
        enable_keyboard
      else
        disable_keyboard
      fi
    '';
  };
in {
  options.hypr-toggle-laptop-kb = with lib; {
    enable = mkEnableOption ''
      hypr-toggle-laptop-kb is a script that toggles the laptop keyboard.
    '';
    hyprDeviceName = mkOption {
      type = types.str;
      default = "at-translated-set-2-keyboard";
      description = ''
        The device name of the laptop keyboard shown in `hyprctl devices`
      '';
    };
    toggleOnLidSwitch = {
      enable = mkEnableOption ''
        Toggle the keyboard when lid is closed and opened.
      '';
      switchName = mkOption {
        type = types.str;
        default = "Lid Switch";
        description = ''
          The name of the switch.
        '';
      };
    };
    waybarIntegration = {
      enable = mkEnableOption ''
        Integrate hypr-toggle-laptop-kb into waybar as a custom button
      '';
      moduleName = mkOption {
        type = types.str;
        default = "hypr-toggle-laptop-kb";
        description = ''
          The name of the waybar module (without the "custom/" prefix)
        '';
      };
      barName = mkOption {
        type = types.str;
        default = "mainBar";
        description = ''
          The name of the bar this module will be appended. This does NOT add the module to a modules array
          it just puts the custom module settings to the correct bar object.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Add it for use
    home.packages = [
      toggleKB
      isEnabled
    ];

    # Implement the script above
    wayland.windowManager.hyprland.settings = {
      "$LAPTOP_KB_ENABLED" = true;
      device = [
        {
          "name" = cfg.hyprDeviceName;
          "enabled" = "$LAPTOP_KB_ENABLED";
        }
      ];

      # Apply switch bind if wanted
      bindl = lib.mkIf cfg.toggleOnLidSwitch.enable [
        ", switch:${cfg.toggleOnLidSwitch.switchName}, exec, ${lib.getExe toggleKB}"
      ];
    };

    # Make a waybar module
    programs.waybar.settings.${cfg.waybarIntegration.barName} = lib.mkIf cfg.waybarIntegration.enable {
      "custom/${cfg.waybarIntegration.moduleName}" = {
        on-click = lib.getExe toggleKB;
        # Runs every second to update the icon
        exec = pkgs.writeShellScript "" ''
          if ${lib.getExe isEnabled}; then
            echo -e '&#xf109; &#xf11c; &#xf00c; \nLaptop keyboard enabled'
          else
            echo -e '&#xf109; &#xf11c; &#xf00d;\nLaptop keyboard disabled'
          fi
        '';
        interval = 1;
        # hide_empty_text = true;
      };
    };
  };
}
