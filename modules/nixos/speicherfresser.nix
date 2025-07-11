{
  pkgs,
  config,
  inputs,
  ...
}: let
  device = "/dev/disk/by-uuid/1c9bb556-309f-4add-a7f0-723a3b96b2f6";
in {
  imports = [inputs.custom-udev-rules.nixosModule];

  # Automount the bid hdd which is not always connected
  sops.secrets."drives/speicherfresser" = {};

  environment.etc.crypttab.text = ''
    speicherfresser UUID=9debc741-b5d9-4721-a2bc-971008511283 ${config.getSopsFile "drives/speicherfresser"} noauto
  '';

  services.udev.customRules = [
    {
      name = "99-speicherfresser";
      rules = ''
        ACTION=="add" ENV{ID_WWN}=="0x5000c500a22a895e" TAG+="systemd" ENV{SYSTEMD_WANTS}="systemd-cryptsetup@speicherfresser.service"
      '';
    }
  ];
  fileSystems."/home/osi/files/remote" = {
    inherit device;
    fsType = "ext4";
    options = [
      "defaults"
      "noatime"
      "x-systemd.automount"
      "x-systemd.device-timeout=0"
      "x-systemd.idle-timeout=60"
      "noauto"
    ];
  };
}
