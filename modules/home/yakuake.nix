{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    inputs.plasma-manager.homeManagerModules.plasma-manager
  ];

  programs.plasma = {
    configFile = {
      # -- yakuake --
      yakuakerc = {
        # Window appearance
        Window = {
          # don't occupy other windows
          KeepAbove = "false";
          # don't close when focus lost
          KeepOpen = "true";

          ToggleToFocus = "false";

          Height = "100";
          Width = "100";

          ShowTabBar = "false";
        };

        # Yakuake shortcuts
        Shortcuts = {
          # Creates a new session with 2x2 terminal grid
          new-session-quad = "Ctrl+Shift+Up";

          # Switches between sessions
          next-session = "Ctrl+Shift+Right";
          previous-session = "Ctrl+Shift+Left";

          # Switches between terminal within a session
          next-terminal = "Shift+Right";
          previous-terminal = "Shift+Left";

          # Set them to 'none' because their defaults conflict with above shortcuts
          move-session-left = "none";
          move-session-right = "none";

          toggle-window-state = "Meta+Y";
        };
      };

      # Autostart yakuake
      "autostart/org.kde.yakuake.desktop"."Desktop Entry" = {
        "DBusActivatable" = "true";
        "Exec" = "${lib.getExe pkgs.yakuake}";
        "Icon" = "yakuake";
        "Name" = "Yakuake";
        "Terminal" = "false";
        "X-DBUS-ServiceName" = "org.kde.yakuake";
        "X-DBUS-StartupType" = "Unique";
        "X-KDE-StartupNotify" = "false";
      };
    };
  };
}
