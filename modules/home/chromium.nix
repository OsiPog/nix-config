{ ... }:
{
  programs.brave = {
    enable = true;
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
