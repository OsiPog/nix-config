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
          disko.devices.disk.disk1.device = "/dev/disk/by-id/some-disk-id"
        You can find out the correct disk ID with
          lsblk
        and
          ls -l /dev/disk/by-id
      '');
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            name = "ESP";
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["umask=0077"];
            };
          };
          luks = {
            size = "100%";
            content = {
              name = "crypted";
              type = "luks"; # during install password is prompted
              settings.allowDiscards = true;
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
