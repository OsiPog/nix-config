{pkgs, ...}: {
  # The hyprland lockscreen
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        ignore_empty_input = true;
        grace = 10;
      };
      auth = {
        fingerprint.enabled = true;
      };
    };
  };

  # Enables the lockscreen when afk
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock --immediate";
        ignore_systemd_inhibit = true;
        ignore_dbus_inhibit = true;
      };
      listener = let
        seconds = s: s;
        minutes = mins: builtins.floor (mins * 60);
        hours = h: builtins.floor (h * 3600);
      in [
        {
          timeout = minutes 3;
          on-timeout = "hyprlock"; # not using loginctl lock-session, because it adds it is without grace and animation
        }
        {
          timeout = minutes 4;
          on-timeout = "systemctl suspend";
        }
        {
          timeout = hours 4;
          on-timeout = "shutdown now";
        }
      ];
    };
  };

  wayland.windowManager.hyprland.settings = {
    # Add hotkeys
    bind = [
      # lock screen
      "$meta, semicolon, exec, loginctl lock-session"
      # lock screen and suspend
      "$meta_CTRL, semicolon, exec, ${pkgs.writeShellScript "" ''
        loginctl lock-session
        systemctl suspend
      ''}"
    ];

    monitor = [
      # This needs to be here so that hyprlock does not crash
      "FALLBACK,1920x1080@60,auto,1"
    ];
  };
}
