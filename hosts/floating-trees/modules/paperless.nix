{
  pkgs,
  config,
  ...
}: {
  services.paperless = {
    mediaDir = "/mnt/zombie-horse/papier";
    settings.PAPERLESS_OCR_LANGUAGE = "deu+eng";
  };

  # automatically send scanned documents to paperless consume
  hardware.sane = {
    enable = true;
    extraBackends = [pkgs.epsonscan2];
  };
  systemd.services.scan-on-print-to-paperless = {
    wantedBy = ["multi-user.target"];
    serviceConfig = {Restart = "always";};
    path = with pkgs; [
      evtest
      config.hardware.sane.backends-package
    ];
    environment = {
      inherit (config.environment.sessionVariables) SANE_CONFIG_DIR LD_LIBRARY_PATH;
      HOME = "/root"; # otherwise scanimage does not find the file
    };
    script = ''
      evtest /dev/input/event0 \
        | while read -r line; do
          if echo "$line" | grep -q "KEY_SYSRQ.*value 1"; then
            scanimage \
              --format=tiff \
              --transfer-format=no \
              --resolution=300 \
              --scan-area=A4 \
              --rotate=Auto \
              --device-name "epsonscan2:ET-2750 Series:583935423031343503:esci2:usb:ES014C:4394" \
              --output-file ${config.services.paperless.consumptionDir}/scan-$(date +%Y%m%d-%H%M%S).tiff
          fi
        done
    '';
  };
}
