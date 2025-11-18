{
  inputs,
  lib,
  ...
}: {
  imports = [inputs.disko.nixosModules.default];

  disko.devices = {
    disk.disk1 = {
      device = lib.mkDefault (throw ''
        Please define the root disk with:
          disko.devices.disk.disk1.device = \"/dev/disk/by-id/some-disk-id\"
        You can find out the correct disk ID with `lsblk` and `ls -l /dev/disk/by-id`.
      '');
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            name = "boot";
            size = "1M";
            type = "EF02";
          };
          esp = {
            name = "ESP";
            size = "500M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            name = "root";
            size = "100%";
            content = {
              type = "lvm_pv";
              vg = "pool";
            };
          };
        };
      };
    };
  };
}
