{pkgs, ...}: {
  # 1. rebuild with this to enable required packages
  environment.systemPackages = with pkgs; [
    sbctl
  ];

  boot.loader.systemd-boot.enable = false;
  boot.loader.limine.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # 2.
  # $ sudo sbctl create-keys
  # $ sudo sbctl enroll-keys --microsoft --firmware-builtin

  # 3. now that secure boot keys are enrolled rebuild with this and reboot
  boot.loader.limine.secureBoot.enable = true;

  # add windows to the bootloader, its on a different drive
  # to find the guid run this and find the vfat partition on the windows drive
  # $ lsblk -o NAME,SIZE,ID,FSTYPE,TYPE,MOUNTPOINT
  # Then run this to and use the guid that points to the vfat partition
  # $ ls -l /dev/disk/by-partuuid
  boot.loader.limine.extraEntries = ''
    /Windows 11
      protocol: efi_boot_entry
      entry: Windows Boot Manager
  '';

  # to allow windows to unattendedly reboot we need to remember last boot entry
  boot.loader.limine.extraConfig = ''
    remember_last_entry: yes
  '';

  # styling
  boot.loader.limine.resolution = "2560x1440x32";
}
