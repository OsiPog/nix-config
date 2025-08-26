{
  config,
  nixosConfig,
  lib,
  ...
}: let
  literal = config.lib.formats.rasi.mkLiteral;
in {
  programs.rofi.theme = with config.lib.stylix.colors.withHashtag; {
    "*" = {
      lightbg = lib.mkForce (literal base00);
      lightfg = lib.mkForce (literal base03);
      selected-normal-text = lib.mkForce (literal base07);
    };

    window = {
      transparency = "real";
      background-color = lib.mkForce (literal "transparent");
      border-color = literal base0D;
      border-radius = literal ((toString nixosConfig.prismarineTheme.border-radius) + "px");
      border = literal "3px";
    };

    mainbox = {
      padding = literal "20px 20px";
      spacing = literal "5px";

      children = map literal ["inputbar" "listview" "message"];
    };

    inputbar = {
      margin-bottom = literal "5px";
      children = map literal ["textbox-prompt-colon" "entry"];
    };
    textbox-prompt-colon = {
      margin = literal "2px 7px 0px 0px";

      expand = false;

      str = ">";
      text-color = lib.mkForce (literal base0C);
    };
    entry = {
      text-color = lib.mkForce (literal base0B);
    };

    listview = {
      scrollable = false;
    };
    element = {
      highlight = literal "bold underline";
      padding = literal "5px";
      children = map literal ["element-icon" "element-text"];
    };
    element-text = {
      background-color = literal "inherit";
      foreground-color = literal "inherit";
      text-color = literal "inherit";
    };
    element-icon = {
      background-color = literal "inherit";
      foreground-color = literal "inherit";
      text-color = literal "inherit";
    };

    message = {
      background-color = literal base00;

      margin = literal "20px 5px 0px 5px";
    };
    textbox = {
      background-color = lib.mkForce (literal base00);
    };
  };
}
