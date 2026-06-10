{pkgs, ...}: let
  inherit (builtins) baseNameOf toString readFile;
  inherit (pkgs.lib.strings) removeSuffix;
in
  {
    file,
    runtimeInputs ? [],
  }:
    pkgs.writeShellApplication {
      name = removeSuffix ".sh" (baseNameOf (toString file));
      text = readFile file;
      inherit runtimeInputs;
    }
