{
  pkgs,
  config,
  lib,
  nixosConfig,
  ...
}: {
  home = {
    packages = with pkgs; [
      hyprshot
      hypridle
      hyprpolkitagent
      ydotool
      hyprmon
      handy
      wtype
    ];
    sessionVariables = {
      XDG_SESSION_TYPE = "wayland";
      XDG_SESSION_DESKTOP = "Hyprland";
      XDG_CURRENT_DESKTOP = "Hyprland";
    };
  };

  # Hyprland would be unusable without a terminal
  programs.kitty.enable = lib.mkDefault true;

  # Fix for electron apps to use wayland
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
  };

  xdg.autostart.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = ["gtk"];
        "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
      };
      hyprland = {
        default = ["hyprland" "gtk"];
        "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
        "org.freedesktop.impl.portal.OpenURI" = ["gtk"];
      };
    };
  };

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      general = {
        # Allow to resize windows with dragging the border
        resize_on_border = true;
      };
      misc = {
        enable_anr_dialog = false; # remove the "application not responding" popup when an app takes a little longer
      };
      debug = {
        disable_logs = false; # enable debug logs
      };

      binds = {
        # To be able to move focus to another monitor even when maximized on current
        movefocus_cycles_fullscreen = false;
      };

      # --- Window Management ---
      general = {
        layout = "dwindle";
      };
      dwindle = {
        force_split = 2;
      };
      scrolling = {
        column_width = 0.8;
        focus_fit_method = 1; # 0 - center, 1 - fit
      };

      # --- Autostart ---
      # run on every reload
      exec = [
      ];
      # run every start
      exec-once = [
        # Auth agent for gui apps
        "systemctl --user start hyprpolkitagent"
        "handy --start-hidden"
        "ydotoold"
      ];

      # --- Keyboard settings ---
      input = let
        inherit (nixosConfig.services.xserver) xkb;
      in {
        kb_layout = xkb.layout;
        kb_variant = xkb.variant;
        kb_options = xkb.options;

        # sensitivity = -0.5;
      };

      device = [
        {
          # override the defaults otherwise it would type gibberish with colemak
          name = "ydotoold-virtual-device";
          kb_layout = "us";
          kb_options = "";
          kb_variant = "";
        }
      ];

      # --- Keybindings ---
      "$meta" = "SUPER";

      bind = let
        arrowsByDirection = {
          u = "Up";
          d = "Down";
          l = "Left";
          r = "Right";
        };

        lettersByDirection = {
          u = "F";
          d = "S";
          l = "R";
          r = "T";
        };

        perDirection = keyByDirection: f: map (x: f x (keyByDirection."${x}")) (builtins.attrNames keyByDirection);
        perDirectionLetter = perDirection lettersByDirection;
        perDirectionArrow = perDirection arrowsByDirection;
      in
        (perDirectionLetter (dir: key: "$meta, ${key}, movefocus, ${dir}"))
        ++ (perDirectionArrow (dir: key: "$meta, ${key}, movefocus, ${dir}"))
        ++ (perDirectionLetter (dir: key: "$meta_CTRL, ${key}, movewindow, ${dir}"))
        ++ (perDirectionArrow (dir: key: "$meta_CTRL, ${key}, movewindow, ${dir}"))
        ++ [
          # application shortcuts
          # Terminal
          "$meta, N, exec, kitty"
          # Firefox (or LibreWolf?)
          "$meta, I, exec, ${config.programs.firefox.package.meta.mainProgram}"

          # window management
          "$meta, W, killactive"
          "$meta, M, fullscreen, 1"
          "$meta_CTRL, M, fullscreen"
          "$meta, K, togglefloating"

          # switch workspaces
          "$meta, J, workspace, r-1"
          "$meta, H, workspace, r+1"

          # move window to workspaceso
          "$meta_CTRL, J, movetoworkspace, r-1"
          "$meta_CTRL, H, movetoworkspace, r+1"

          # Taking screenshots
          "$meta, A, exec, pidof hyprshot || hyprshot -m region --clipboard-only --freeze"
          "$meta_CTRL, A, exec, pidof hyprshot || hyprshot -m region --freeze -o ~/Pictures"

          "$meta, O, exec, handy --toggle-transcription"
          "$meta_SHIFT, O, exec, handy --toggle-post-process"
        ];

      # Binds here will be repeated on press
      binde = let
        resizeFactor = "50";
      in [
        # resize window
        "$meta, G, resizeactive, -${resizeFactor} -${resizeFactor}"
        "$meta, D, resizeactive, ${resizeFactor} ${resizeFactor}"

        # Volume keys
        # (the brightness keys are handled in the laptop file)
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_SINK@ 10%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_SINK@ 10%-"
      ];

      # The binds here are for the mouse
      bindm = [
        "$meta, mouse:272, movewindow" # Move when super and left click
        # ", mouse:275, movewindow" # or with mouse 5 (lower side)
      ];

      # --- WINDOW RULES
      windowrule = [
        "stay_focused on, match:title ^Hyprland Polkit Agent$"
        # "dimaround, title:^Hyprland Polkit Agent$"

        # browser saving action
        "float on, match:title ^Save File$"
        "float on, match:title .*wants to save$"

        # launch android studio in a accessable position
        "monitor 0, match:class jetbrains-studio"

        # The base gnucash window should be tiled, everything else should be floating
        "float on, match:class gnucash"
        "tile on, match:title .*- GnuCash$"

        # Gamescope errors should be float
        "float on, match:title Gamescope WSI Layer Error"
      ];
    };
  };
}
