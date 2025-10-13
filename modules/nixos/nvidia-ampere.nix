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

  # disable sleeping because that does not work
  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';
}
