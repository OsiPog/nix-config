{
  pkgs,
  config,
  ...
}: let
  sddmTheme = pkgs.where-is-my-sddm-theme.override {
    themeConfig.General = with config.lib.stylix.colors.withHashtag; {
      hideCursor = "true"; # hides mouse
      passwordFontSize = "48";
      passwordInputWidth = "1";
      passwordCharacter = "•";

      # Colors
      backgroundFill = base00;
      basicTextColor = base05;
      passwordCursorColor = base0B;
    };
  };
in {
  services.displayManager = {
    sddm = {
      package = pkgs.kdePackages.sddm;
      extraPackages = with pkgs.kdePackages; [
        plasma5support
      ];
      theme = "${sddmTheme}/share/sddm/themes/where_is_my_sddm_theme";
    };
  };
}
