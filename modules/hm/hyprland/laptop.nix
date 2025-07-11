{pkgs, ...}: {
  home.packages = with pkgs; [
    brightnessctl # for setting the brightness of built-in monitor

    # Sometimes, when I would connect the laptop to the docking station, not all screens work.
    # This script disables all external screens at once and turns them on again (and this works lol)
    (pkgs.writeShellApplication {
      name = "hypr-fix-screens";
      text = ''
        # Enable eDP-1 (will crash if not enabled)
        hyprctl keyword monitor "eDP-1"

        # Get all connected monitors, (except eDP-1, the internal screen) and disable all of them
        hyprctl monitors \
        | grep Monitor \
        | awk '{print $2}' \
        | grep -v "eDP-1" \
        | xargs -I {} hyprctl keyword monitor "{}, disable"

        # Wait 2 seconds
        sleep 2

        # Reload config -> re-enables all configured monitors
        hyprctl reload

        # Disable eDP-1
        hyprctl keyword monitor "eDP-1, disable"
      '';
    })

    # Another script that tries to fix a flickering screen at my desk (probably related to docking station)
    (pkgs.writeShellApplication {
      name = "hypr-fix-flicker-screen";
      text = ''
        # intentionally set invalid resolution@framerate
        # now the monitor is on, but it does not need to show hdmi input
        hyprctl keyword monitor "$MONITOR, 1920x1080@30, auto, preffered"

        # let him relax while being awake but without hdmi input
        sleep 30

        # put him to sleep
        hyprctl dispatch dpms toggle "$MONITOR"

        # let him sleep
        sleep 30

        # wake him up
        hyprctl dispatch dpms toggle "$MONITOR"

        # snooze a little
        sleep 10

        # everyting to be normal (sometimes the flicker stopped now)
        hyprctl reload
      '';
    })
  ];

  wayland.windowManager.hyprland.settings = {
    monitor = [
      # Mirror new monitors to laptop monitor
      ", preffered, auto, 1, mirror, eDP-1"
    ];

    input.touchpad = {
      # 1 finger -> left click
      # 2 fingers -> right click
      # 3 fingers -> middle click
      clickfinger_behavior = true;

      # scrolling is like moving a piece of paper
      # scrolling up when swiping down
      natural_scroll = true;
    };

    # repeated binds
    binde = [
      # Brightness keys
      ", code:233, exec, brightnessctl set +10%"
      ", code:232, exec, brightnessctl set 10%-"
    ];

    # lockscreen binds
    # do certain actions on lid switch
    bindl = let
      docked = pkgs.writeShellScript "" ''
        [ $(hyprctl monitors | grep -c '(ID ') -ge 2 ]
      '';

      closeLid = pkgs.writeShellScript "" ''
        # disable monitor if it is not the only one
        if ${docked}; then
          hyprctl keyword monitor "eDP-1, disable"
        # otherwise lock the screen
        else
          loginctl lock-session
        fi
      '';

      openLid = pkgs.writeShellScript "" ''
        # enable monitor
        hyprctl reload

        # Run hyprlock if laptop is not docked
        if ! ${docked}; then
          loginctl lock-session
        fi
      '';
    in [
      # switch behaviour
      ", switch:on:Lid Switch, exec, ${closeLid}"
      ", switch:off:Lid Switch, exec, ${openLid}"
    ];
  };
}
