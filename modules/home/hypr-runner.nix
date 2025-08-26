# The runner for hyprland is using a combination of wofi and rofi. Rofi is generally more lightweight while Wofi has
# touch support which is essential to tablet mode.
{pkgs, ...}: {
  home.packages = with pkgs; [
    wofi-emoji
  ];

  # Highly supported runner
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;

    plugins = with pkgs; [
      rofi-emoji-wayland
    ];
  };

  programs.wofi = {
    enable = true;
    settings = {
      normal_window = true;
    };
  };

  services.gpg-agent.pinentry.package = pkgs.pinentry-rofi.override {
    rofi = pkgs.rofi-wayland;
  };

  wayland.windowManager.hyprland.settings.bind = [
    # Rofi menus
    # launcher
    # "$meta, O, exec, pidof rofi || rofi -show drun"
    # window selector
    # "$meta, E, exec, pidof rofi || rofi -show window"
    # emoji
    # "$meta, U, exec, pidof rofi || rofi -show emoji"
    # Pass
    "$meta, P, exec, pidof rofi || wofi-pass --type"

    # Wofi menus
    # launcher
    "$meta, E, exec, pidof wofi || wofi --show drun"
    # emoji
    "$meta, U, exec, pidof wofi || wofi-emoji"
  ];
}
