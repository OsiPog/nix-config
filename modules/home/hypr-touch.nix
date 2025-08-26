{pkgs, ...}: {
  wayland.windowManager.hyprland = {
    # Plugin for touch inputs
    plugins = with pkgs.hyprlandPlugins; [
      hyprgrass
    ];

    settings = {
      # Touch input is sent to the touchscreen
      input.touchdevice = {
        output = "eDP-1";
        transform = 0;
      };
      input.tablet.output = "eDP-1";

      # settings for above plugin
      "plugin:touch-gestures" = {
        sensitivity = 4.0;
        workspace_swipe_fingers = 3;
        workspace_swipe_edge = false;
        emulates_touchpad_swipe = false;
        edge_margin = 50;

        # Mouse binds
        hyprgrass-bindm = [
          ", longpress:3, movewindow"
          ", longpress:4, resizewindow"
        ];

        hyprgrass-bind = [
          ", swipe:4:u, movetoworkspace, r-1"
          ", swipe:4:d, movetoworkspace, r+1"
          ", edge:r:l, exec, pkill hyprshot || hyprshot -m region --clipboard-only --freeze"
          ", edge:l:r, overview:toggle" # swipe from left to right
          # swipe from bottom to top does not work
          ", edge:u:d, exec, pkill waybar || waybar" # swipe from top to bottom
        ];

        hyprgrass-bindl = [
          ", edge:u:d, exec, pkill waybar || waybar" # swipe from top to bottom
        ];
      };

      gestures = {
        workspace_swipe = true;
        workspace_swipe_cancel_ratio = 0.15;
      };
    };
  };
}
