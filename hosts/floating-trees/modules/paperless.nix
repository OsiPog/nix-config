{
  pkgs,
  config,
  ...
}: {
  services.paperless = {
    mediaDir = "/mnt/zombie-horse/papier";
    settings.PAPERLESS_OCR_LANGUAGE = "deu+eng";
  };

  hardware.sane = {
    enable = true;
    extraBackends = [pkgs.epsonscan2];
  };

  systemd.services.scan-to-paperless = {
    description = "Scan document and send to Paperless consumption folder";
    restartIfChanged = false; # do not auto-start on nixos-rebuild switch
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
    };
    path = with pkgs; [
      ps
      usbutils
      config.hardware.sane.backends-package
    ];
    environment = {
      inherit (config.environment.sessionVariables) SANE_CONFIG_DIR LD_LIBRARY_PATH;
      HOME = "/root";
    };
    script = ''
      # 1. reset usb for a fresh connection
      usbreset 04b8:112a
      # 2. start printing with timeout guard
      timeout --signal=KILL 20 scanimage \
        --format=tiff \
        --transfer-format=no \
        --resolution=300 \
        --scan-area=A4 \
        --rotate=Auto \
        --mode=Monochrome \
        --device-name "epsonscan2:ET-2750 Series:583935423031343503:esci2:usb:ES014C:4394" \
        --output-file ${config.services.paperless.consumptionDir}/scan-$(date +%Y%m%d-%H%M%S).tiff
    '';
  };

  systemd.services.listen-for-print-button = {
    description = "Listen for scanner button press and trigger scan";
    wantedBy = ["multi-user.target"];
    serviceConfig = {Restart = "always";};
    path = with pkgs; [evtest systemd];
    script = ''
      evtest /dev/input/event0 \
        | while read -r line; do
          if echo "$line" | grep -q "KEY_SYSRQ.*value 1"; then
            systemctl start scan-to-paperless.service
          fi
        done
    '';
  };

  # Allow the "hass" group (e.g. Home Assistant) to start the scan service
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id === "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") === "scan-to-paperless.service" &&
          action.lookup("verb") === "start" &&
          subject.isInGroup("hass")) {
        return polkit.Result.YES;
      }
    });
  '';

  services.home-assistant.config.shell_command.scan_to_paperless = "systemctl start scan-to-paperless";
}
