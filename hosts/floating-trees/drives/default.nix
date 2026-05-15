# Automatically mount encrypted drives at boot: https://blog.pankajraghav.com/2024/09/17/AUTOMOUNT.html
{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib.attrsets) mapAttrs' mapAttrsToList;
  inherit (lib.strings) concatLines;

  driveIdsByName = {
    blaze = "ata-ST4000VN000-1H4168_Z306AQXL-part1";
    husk = "ata-ST4000VN000-1H4168_Z300LXHB-part1";
    ocelot = "ata-ST4000VN000-1H4168_Z305F234-part1";
    zombie-horse = "ata-WDC_WD100EMAZ-00WJTA0_2YJXGUXD-part1";
  };
in {
  environment.systemPackages = [pkgs.mergerfs];

  # Setup the secrets of each host in `drives`
  sops.secrets =
    mapAttrs' (name: _: {
      name = "drives/${name}";
      value = {sopsFile = ./secrets.yaml;};
    })
    driveIdsByName;

  # automatic decryption of the drives
  environment.etc.crypttab.text = concatLines (
    mapAttrsToList (name: id: ''
      ${name} /dev/disk/by-id/${id} ${config.getSopsFile "drives/${name}"}
    '')
    driveIdsByName
  );

  # register the decrypted drives
  fileSystems =
    (
      mapAttrs' (name: _: {
        name = "/mnt/${name}";
        value = {
          device = "/dev/mapper/${name}";
          fsType = "ext4";
          options = [
            "defaults"
            "noatime"
            # "noauto" # the drive should automatically be mounted on boot
            # "x-systemd.automount"
            # "x-systemd.idle-timeout=3min"
          ];
        };
      })
      driveIdsByName
    )
    # create a merged mountpoint for the 3 4TB drives
    // {
      "/mnt/mob-farm" = {
        device = "/mnt/blaze:/mnt/husk:/mnt/ocelot";
        fsType = "fuse.mergerfs";
        depends = [
          "/mnt/blaze"
          "/mnt/husk"
          "/mnt/ocelot"
        ];
        options = [
          "defaults"
          "allow_other"
          "use_ino"
          "cache.files=partial"
          "dropcacheonclose=true"
          "category.create=mfs"
        ];
      };
    };
}
