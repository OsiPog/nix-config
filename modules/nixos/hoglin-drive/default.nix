# Automatically mount encrypted drive at boot: https://blog.pankajraghav.com/2024/09/17/AUTOMOUNT.html
{
  lib,
  config,
  ...
}: let
  name = "hoglin";
  id = "ata-WDC_WD120EDAZ-11F3RA0_5PJWD4TB-part1";
in {
  sops.secrets."drives/${name}" = {
    sopsFile = ./secrets.yaml;
  };

  environment.etc.crypttab.text = ''
    ${name} /dev/disk/by-id/${id} ${config.getSopsFile "drives/${name}"}
  '';

  fileSystems."/mnt/${name}" = {
    device = "/dev/mapper/${name}";
    fsType = "ext4";
    options = [
      "defaults"
      "noatime"
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=3min"
      "users"
    ];
  };
}
