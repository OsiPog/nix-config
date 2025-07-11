{config, ...}: {
  services.syncthing = {
    enable = true;
    settings = {
      folders = {
        "written-mind" = {
          enable = true;
          path = "/home/${config.home.username}/files/local/written-mind";
          devices = ["phone"];
        };
      };
      devices = {
        "phone" = {
          id = "4QPQX3G-WOEEQUD-QJASCBF-DJN6D4H-SXDXHHR-NCP4D4P-2YEIESD-BMXVYAS";
        };
      };
    };
  };
}
