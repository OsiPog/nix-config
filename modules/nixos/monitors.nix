{...}: let
  monitors = [
    # { # Laptop monitor
    #   resolution = "1920x1200";
    #   position = "auto";
    #   scale = 1.2;
    #   additional = "";
    #   names = [
    #     "Chimei Innolux Corporation 0x143F"
    #   ];
    # }
    {
      # Portable monitor
      resolution = "1920x1080";
      position = "auto";
      scale = 1;
      additional = "transform, 3";
      names = [
        "RGT 0x5211 0x00000401"
        "DZX EVP-304 000000000000"
      ];
    }
    {
      # Landscape desktop monitor
      resolution = "2560x1440";
      position = "0x240";
      scale = 1;
      additional = "";
      names = [
        "ViewSonic Corporation VA3209-QHD WYM241340384"
      ];
    }
    {
      # Portrait desktop monitor
      resolution = "1920x1080";
      position = "2560x0";
      scale = 1;
      additional = "transform, 1";
      names = [
        "LG Electronics 27EA53 312NDNU32431"
        "LG Electronics 27EA53 0x01010101"
        "Invalid Vendor Codename - RTK 0x1D1A 0x01010101"
      ];
    }
  ];
in {
  # All home manager specific options
  home-manager.sharedModules = [
    ({...}: {
      # Config for hyprland
      wayland.windowManager.hyprland.settings.monitor = builtins.concatLists (
        map (
          monitor:
            map (
              name: "desc:${name}, ${monitor.resolution}, ${monitor.position}, ${builtins.toString monitor.scale}, ${monitor.additional}"
            )
            monitor.names
        )
        monitors
      );
    })
  ];
}
