{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  # File names that are reused throughout this module
  themeName = "stylix";
  colorschemeName = "stylix-colors";

  # Function that takes a base16 color id (like 0A) and outputs a string with rgb values (like "129,89,199)
  rgbString = colorID:
    builtins.concatStringsSep ","
    (map (x: config.lib.stylix.colors."${colorID}-${x}") ["rgb-r" "rgb-g" "rgb-b"]);
in {
  imports = [
    inputs.plasma-manager.homeManagerModules.plasma-manager
  ];

  # I am hardcoding this theme as I think it is the only theme a yakuake user should use
  home.file.".local/share/yakuake/kns_skins/breeze-minimal".source = builtins.fetchGit {
    url = "ssh://git@github.com/OsiPog/breeze-minimal.git";
    rev = "3142f04c467a19611bbbe145df48316305f6b684";
  };

  programs.plasma.configFile.yakuakerc = {
    # Set the yakuake theme
    Appearance = {
      Skin = "breeze-minimal";
      SkinInstalledWithKns = "true"; # Sometimes in life, lying is the way to go
    };

    # Set the terminal theme
    "Desktop Entry" = {
      DefaultProfile = "${themeName}.profile";
    };
  };

  # Install my custom terminal theme
  home.file.".local/share/konsole/${themeName}.profile" = {
    text = ''
      [Appearance]
      ColorScheme=${colorschemeName}
      Font=Hack,10,-1,5,50,0,0,0,0,0
      DimmValue=50

      [General]
      Command=$SHELL
      Name=${themeName}
      Parent=FALLBACK/
      TerminalCenter=true
      TerminalMargin=15
      DimWhenInactive=true

      [Interaction Options]
      TrimTrailingSpacesInSelectedText=true

      [Scrolling]
      ScrollBarPosition=2
    '';
  };

  # https://github.com/cskeeters/base16-konsole/blob/master/templates/default.mustache
  home.file.".local/share/konsole/${colorschemeName}.colorscheme" = {
    text = ''
      [Background]
      Color=${rgbString "base00"}

      [BackgroundIntense]
      Color=${rgbString "base03"}

      [Color0]
      Color=${rgbString "base00"}

      [Color0Intense]
      Color=${rgbString "base03"}

      [Color1]
      Color=${rgbString "base08"}

      [Color1Intense]
      Color=${rgbString "base08"}

      [Color2]
      Color=${rgbString "base0B"}

      [Color2Intense]
      Color=${rgbString "base0B"}

      [Color3]
      Color=${rgbString "base0A"}

      [Color3Intense]
      Color=${rgbString "base0A"}

      [Color4]
      Color=${rgbString "base0D"}

      [Color4Intense]
      Color=${rgbString "base0D"}

      [Color5]
      Color=${rgbString "base0E"}

      [Color5Intense]
      Color=${rgbString "base0E"}

      [Color6]
      Color=${rgbString "base0C"}

      [Color6Intense]
      Color=${rgbString "base0C"}

      [Color7]
      Color=${rgbString "base05"}

      [Color7Intense]
      Color=${rgbString "base07"}

      [Foreground]
      Color=${rgbString "base05"}

      [ForegroundIntense]
      Color=${rgbString "base07"}

      [General]
      Anchor=0.5,0.5
      Blur=true
      Description=color-scheme
      FillStyle=Tile
      Opacity=${lib.strings.floatToString config.stylix.opacity.terminal}
    '';
  };
}
