{
  flake,
  lib,
  inputs,
  nixosConfig,
  ...
}: {
  home.stateVersion = lib.mkDefault "25.11";

  imports = with flake.homeModules;
    [
      # shell
      fish
      git

      # terminal
      kitty

      # Window manager
      hyprland # base config
      hypr-laptop # for laptops
      hypr-touch # for laptops
      waybar # utility bar
      hypr-lockscreen # lockscreen with auto enable on inactivity
      hypr-runner
      hypr-workspaces
      quickshell

      # code editor
      vscode
      # nvf
      helix

      # web browser
      firefox
      chromium # when firefox fails

      # password manager
      password-store

      # Some common desktop apps I need
      desktop-apps
      cli-tools
      godot

      uni
    ]
    ++ (with inputs.nix-config-private.homeModules; [
      work
    ]);

  programs.gpg.publicKeys = [
    {
      trust = 5;
      source = ./0x675D2CB5013E8731.pub;
    }
  ];
  wayland.windowManager.hyprland.settings = let
    first = "desc:ViewSonic Corporation VA3209-QHD WYM241340384";
    second = "desc:LG Electronics LG HDR 4K 0x0002912D";
  in {
    monitor = [
      "${first}, 2560x1440@59.95100, 4000x560, 1.00"
      "${second}, 2560x1440@59.95100, 2560x0, 1.00, transform, 3"
    ];
    workspace = [
      "m[${second}], layoutopt:direction:down, layout:scrolling"
    ];
  };

  programs.firefox.policies.Bookmarks = lib.pipe nixosConfig.lib.network.proxiedPorts [
    builtins.attrValues
    (lib.filter (p: p.proxy.method == "virtual-host"))
    (
      map (p: {
        Title = p.proxy.domain;
        URL = p.getAddress "https://<domain>";
      })
    )
  ];
}
