{pkgs, ...}: {
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
  systemd.user.services.start-noisetorch = {
    enable = true;
    wantedBy = ["default.target"];
    serviceConfig.ExecStart = "${pkgs.noisetorch}/bin/noisetorch -i";
  };
}
