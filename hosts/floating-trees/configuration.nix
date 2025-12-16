{
  flake,
  pkgs,
  ...
}: {
  imports = with flake.nixosModules; [
    ./hardware-configuration.nix
    shared

    disko-fsd

    drive-blaze-husk
    pcspkr
  ];

  disko.devices.disk.disk1.device = "/dev/disk/by-id/ata-EDILOCA_ES106_1TB_AA000000000000050186";

  systemd.services.beep-unlocked = {
    path = [pkgs.beep];
    wantedBy = ["basic.target"];
    script = ''
      G4=392
      F4S=370
      E4B=311
      A3=220
      G3S=208
      E4=330
      A4S=466
      C5=523

      G5=784
      F5S=740
      D5S=622
      A4=440
      G4S=415
      E5=659
      G5S=831
      C6=1047

      SPEED=120

      beep -f $G5 -l $SPEED
      beep -f $F5S -l $SPEED
      beep -f $D5S -l $SPEED
      beep -f $A4 -l $SPEED
      beep -f $G4S -l $SPEED
      beep -f $E5 -l $SPEED
      beep -f $G5S -l $SPEED
      beep -f $C6 -l $(($SPEED * 2))
    '';
    serviceConfig.Type = "oneshot";
  };

  # Don't change, will break things!
  system.stateVersion = "25.11";
}
