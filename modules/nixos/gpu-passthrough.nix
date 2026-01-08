{lib, ...}: let
  inherit (lib) mkBefore;
in {
  boot.initrd.kernelModules = mkBefore [
    "vfio_pci"
    "vfio"
    "vfio_immu_type1"
  ];
}
