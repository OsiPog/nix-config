{pkgs, ...}: let
  # A fix for obsidian to properly open attachments:
  # basically making electron think its on gnome so that is uses "gio" (from glib) to open programs
  # https://forum.obsidian.md/t/obsidian-freezes-entirely-when-an-attachment-is-open-with-an-external-program/78861
  obsidianOverride = pkgs.obsidian.overrideAttrs (prev: {
    installPhase =
      prev.installPhase
      + ''
        wrapProgram $out/bin/obsidian \
          --prefix PATH : ${pkgs.glib}/bin \
          --set XDG_CURRENT_DESKTOP "GNOME"
      '';
  });
in {
  home.packages = with pkgs; [
    gnome-disk-utility # format disks
    libreoffice # office suite
    loupe # Image Viewer
    nautilus # File Browser
    obsidianOverride # markdown note taking app
    prismlauncher # Open Source Minecraft Launcher
    signal-desktop # secure messaging
    vlc # Media Player
    xournalpp # stylus note taking app
    gimp # image editor
    krita # best drawing
    cheese # camera app
    audacity # audio editing
  ];

  # Default apps
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "video/mp4" = ["vlc.desktop"];
      "image/jpeg" = ["org.gnome.Loupe.desktop"];
      "image/png" = ["org.gnome.Loupe.desktop"];
    };
  };
}
