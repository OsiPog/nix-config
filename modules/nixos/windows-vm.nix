# libvirt/QEMU set up for running a Windows guest.
{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (builtins) attrNames;
  inherit (lib) pipe;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.lists) findFirst;

  inList = e: list: (findFirst (x: x == e) null list) != null;
in {
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      # Windows 11 wants a TPM 2.0. The UEFI firmware it also wants now ships
      # with QEMU by default, so there is no `ovmf` option to set any more.
      swtpm.enable = true;
    };
  };

  programs.virt-manager.enable = true;

  # Windows drivers for virtio devices. Attach as a second CD-ROM during the
  # guest install so it can use virtio disk/network/GPU instead of the emulated
  # AHCI, e1000e and VGA that Windows supports out of the box.
  environment.systemPackages = [pkgs.virtio-win];

  # Same pattern as the podman module: wheel users get VM access.
  users.extraGroups.libvirtd.members = pipe config.users.users [
    (filterAttrs (_: value: inList "wheel" value.extraGroups))
    attrNames
  ];
}
