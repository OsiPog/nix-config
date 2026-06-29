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

    ./jellyfin.nix
    ./drives
  ];

  disko.devices.disk.disk1.device = "/dev/disk/by-id/ata-EDILOCA_ES106_1TB_AA000000000000050186";

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
  };
  systemd.services.opencloud.path = [pkgs.inotify-tools];

  services.home-assistant = {
    config = {
      "automation ui" = "!include automations.yaml";
      "scene ui" = "!include scenes.yaml";
      "script ui" = "!include scripts.yaml";
      recorder = {};
    };
    extraComponents = [
      "default_config"
      "isal"
    ];
    customComponents = with pkgs.home-assistant-custom-components; [
      tuya_local

      (pkgs.buildHomeAssistantComponent rec {
        owner = "damacus";
        domain = "robovac";
        version = "v2.4.3-beta.1";

        src = pkgs.fetchFromGitHub {
          inherit owner;
          repo = domain;
          rev = version;
          hash = "sha256-iQNXHghUznCqc0FNx4rUb6o9JicK8IvAhFG95hm0DkQ=";
        };
      })
    ];
  };

  # this is fine
  services.authelia.instances.default.settings.access_control.default_policy = "one_factor";

  # Don't change, will break things!
  system.stateVersion = "25.11";
}
