{...}: {
  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Noise cancellation software
  programs.noisetorch.enable = true;

  # Start noisetoach after login
  systemd.user.services.autostart-noisetorch = {
    description = "Run noisetorch on the default sink at boot";
    wantedBy = ["multi-user.target"];
    serviceConfig.ExecStart = "noisetorch -i";
  };
}
