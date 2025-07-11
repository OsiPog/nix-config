{pkgs, ...}: {
  programs.chromium = {
    enable = true;
    package = pkgs.brave;
    extensions = [
      {
        # Vimium
        id = "dbepggeogbaibhgnhhndojpepiihcmeb";
      }
      {
        # Vue Devtools
        id = "nhdogjmejiglipccpnnnanhbledajbpd";
      }
    ];
  };
}
