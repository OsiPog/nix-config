{
  pkgs,
  lib,
  ...
}:

pkgs.writeShellApplication {
  name = "kitty-tab-switcher";
  
  runtimeInputs = with pkgs; [
    kitty
    jq
    fzf
  ];

  text = ''
    cd ${./.}
    
    bash switcher.sh "$@"    
  '';
}
