{pkgs, ...}: {
  wayland.windowManager.hyprland = {
    plugins = with pkgs.hyprlandPlugins; [
      # hyprexpo
      hyprspace
    ];

    settings = {
      # "plugin:hyprexpo" = {
      #   inherit columns;
      #   enable_gesture = false;
      #   workspace_method = "center current";
      # };
      "plugin:overview" = {
        hideBackgroundLayers = true; # no wallpaper
        hideTopLayers = true; # no bar
        # panelHeight = 250;

        onBottom = true;

        # hide as many empty workspaces as possible
        showNewWorkspace = false;
        showEmptyWorkspace = false;

        disableGestures = true;
        affectStrut = false;
      };

      bind = [
        # "$meta, O, hyprexpo:expo, toggle"
        "$meta, O, overview:toggle"
      ];

      animation = [
        "workspaces, 1, 5, default, slidevert"
      ];
    };
  };
}
