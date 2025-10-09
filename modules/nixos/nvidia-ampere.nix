{...}: {
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    open = true;
    powerManagement = {
      enable = true;
    };
    modesetting.enable = true;
    nvidiaSettings = true;
  };
}
