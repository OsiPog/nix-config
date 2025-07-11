{...}: {
  # Power management using auto-cpufreq
  powerManagement.enable = true; # basic NixOS powermanagement
  services.auto-cpufreq.enable = true;
  services.tlp.enable = false; # to avoid conflicts
  services.power-profiles-daemon.enable = false; # same here
  services.auto-cpufreq.settings = {
    battery = {
      governor = "powersave";
      turbo = "never";
      scaling_max_freq = 800000; # I'd rather wait a bit than have battery drain
    };
    charger = {
      governor = "performance";
      turbo = "always"; # Turbo should be used on charger
    };
  };

  # Enable bluetooth
  hardware.bluetooth.enable = true;

  # The laptop has a thunderbolt port
  services.hardware.bolt.enable = true;
}
