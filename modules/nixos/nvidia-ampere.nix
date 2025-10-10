{...}: {
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    open = true;
    powerManagement = {
      enable = false; # TODO: currently the gpu does not wake up from sleep so we do not allow sleep
    };
    modesetting.enable = true;
    nvidiaSettings = true;
  };
}
