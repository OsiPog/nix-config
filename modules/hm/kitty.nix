{pkgs, self, lib, ...}: {
  programs.kitty = {
    enable = true;
    settings = {
      enable_audio_bell = "no";
      allow_remote_control = "yes";
    };
    extraConfig = ''
      map ctrl+shift+t new_tab_with_cwd

      # Thanks a lot to https://github.com/kovidgoyal/kitty-fosshack2024/issues/1
      map ctrl+shift+e launch --type=overlay --allow-remote-control ${lib.getExe self.packages.${pkgs.system}.kitty-tab-switcher}
    '';
  };
}
