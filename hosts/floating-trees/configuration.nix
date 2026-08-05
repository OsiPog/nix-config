{
  flake,
  pkgs,
  config,
  ...
}: {
  imports = with flake.nixosModules; [
    ./hardware-configuration.nix
    shared

    disko-fsd

    pcspkr

    makemkv

    ./modules/jellyfin.nix
    ./modules/home-assistant.nix
    ./modules/drives
    ./modules/vikunja.nix
  ];

  disko.devices.disk.disk1.device = "/dev/disk/by-id/ata-EDILOCA_ES106_1TB_AA000000000000050186";

  hardware.bluetooth.enable = true;

  # systemd.services.beep-unlocked = {
  #   path = [pkgs.beep];
  #   wantedBy = ["basic.target"];
  #   script = ''
  #     G5=784
  #     F5S=740
  #     D5S=622
  #     A4=440
  #     G4S=415
  #     E5=659
  #     G5S=831
  #     C6=1047

  #     SPEED=120

  #     beep -f $G5 -l $SPEED
  #     beep -f $F5S -l $SPEED
  #     beep -f $D5S -l $SPEED
  #     beep -f $A4 -l $SPEED
  #     beep -f $G4S -l $SPEED
  #     beep -f $E5 -l $SPEED
  #     beep -f $G5S -l $SPEED
  #     beep -f $C6 -l $(($SPEED * 2))
  #   '';
  #   serviceConfig.Type = "oneshot";
  # };

  # users.users.nginx = {
  #   # for transferring website data
  #   openssh.authorizedKeys = {inherit (config.users.users.leaf.openssh.authorizedKeys) keys;};
  #   useDefaultShell = true;
  # };

  # setup husk group
  users.groups.husk = {};

  # intel gpu
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-ocl
      intel-vaapi-driver
      intel-compute-runtime
    ];
  };

  # --- OPENCLOUD read husk
  # users.users.opencloud.extraGroups = ["husk"];
  # fileSystems."${config.services.opencloud.stateDir}/storage/users/users/osi/written-mind" = {
  #   device = "/mnt/zombie-horse/cloud/written-mind";
  #   fsType = "none";
  #   options = ["bind"];
  # };
  services.opencloud.environment = {
    OC_SHARING_PUBLIC_SHARE_MUST_HAVE_PASSWORD = "false";
    STORAGE_USERS_POSIX_WATCH_FS = "true";
    FRONTEND_ARCHIVER_MAX_SIZE = "10000000000";
    OC_LOG_LEVEL = "WARN";
  };
  systemd.services.opencloud.path = [pkgs.inotify-tools];

  # this is fine
  services.authelia.instances.default.settings.access_control.default_policy = "one_factor";

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

  # Don't change, will break things!
  system.stateVersion = "25.11";
}
