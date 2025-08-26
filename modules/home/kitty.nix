{pkgs, inputs, lib, ...}: {
  programs.kitty = {
    enable = true;
    settings = {
      enable_audio_bell = "no";
      allow_remote_control = "yes";
    };
    extraConfig = ''
      map ctrl+shift+t new_tab_with_cwd

      map ctrl+shift+e launch --type=overlay --allow-remote-control ${lib.getExe inputs.kitty-tab-switcher.packages.${pkgs.system}.default}
    '';
  };
}
