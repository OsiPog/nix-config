{
  pkgs,
  lib,
  inputs,
  config,
  ...
}: {
  home.packages = with pkgs; [
    godot_4
  ];

  # Add extension to vscode
  programs.vscode.profiles.default = lib.mkIf config.programs.vscode.enable {
    userSettings."godotTools.editorPath.godot4" = lib.getExe pkgs.godot_4;
    extensions = with inputs.nix-vscode-extensions.extensions.${pkgs.system};
    with vscode-marketplace; [
      geequlim.godot-tools
    ];
  };

  # Add window rules to hyprland
  wayland.windowManager.hyprland.settings.windowrulev2 = lib.mkIf config.wayland.windowManager.hyprland.enable [
    "float, title:.*\\(DEBUG\\)$"
    "size 1280 720, title:.*\\(DEBUG\\)$"

    "tile, title:.*Godot Engine$"
  ];
}
