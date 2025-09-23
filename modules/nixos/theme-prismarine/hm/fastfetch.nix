{
  pkgs,
  lib,
  ...
}: {
  programs.fastfetch.settings.logo = {
    width = lib.mkDefault 40;
    source = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
  };
}
