{
  pkgs,
  lib,
  config,
  ...
}: {
  options.matcha = with lib; {
    enable = mkEnableOption "a wayland idle inhibitor";
    waybarIntegration = {
      enable = mkEnableOption "declare a waybar module that can be used";
      moduleName = mkOption {
        default = "matcha";
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
    disableOnLidSwitch = {
      enable = mkEnableOption ''
        Disable when lid is closed.
      '';
      switchName = mkOption {
        type = types.str;
        default = "Lid Switch";
        description = ''
          The name of the switch.
        '';
      };
    };
  };

  config = lib.mkIf config.matcha.enable {
    home.packages = [
      pkgs.matcha

      (pkgs.writeShellScriptBin "matcha-toggle" ''
        if pidof matcha >/dev/null; then
          pkill matcha
        else
          matcha --daemon &
        fi
      '')
    ];

    # Waybar integration
    programs.waybar.settings.${config.matcha.waybarIntegration.barName} = lib.mkIf config.matcha.waybarIntegration.enable {
      "custom/${config.matcha.waybarIntegration.moduleName}" = let
        # Toggles matcha, kill if running, start if not running
        # Checks whether match is running
        statusCheck = pkgs.writeShellScript "" ''
          if pidof matcha>/dev/null; then
            echo -e '&#xf109; &#xf7b6;\nIdle Inhibitor Enabled'
          else
            echo -e '&#xf109; &#xf186;\nIdle Inhibitor Disabled'
          fi
        '';
      in {
        # Check status every second
        exec = statusCheck;
        interval = 1;
        # Toggle on click
        on-click = "matcha-toggle";
      };
    };

    # Hyprland integration
    wayland.windowManager.hyprland.settings.bindl = lib.mkIf config.matcha.disableOnLidSwitch.enable [
      ", switch:${config.matcha.disableOnLidSwitch.switchName}, exec, pkill matcha"
    ];
  };
}
