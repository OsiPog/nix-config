{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  imports = [inputs.custom-udev-rules.nixosModule];

  boot = {
    initrd.kernelModules = lib.mkBefore [
      "vfio_pci"
      "vfio"
      "vfio_iommu_type1"

      "kvmfr" # for looking-glass
    ];

    kernelParams = [
      "amd_iommu=on"
      "iommu=pt"

      "vfio-pci.ids=1002:7590,1002:ab40"

      "kvmfr.static_size_mb=64" # looking-glass buffer
    ];
  };

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      # shared directories
      vhostUserPackages = [
        (pkgs.virtiofsd.overrideAttrs (prev: rec {
          src = pkgs.fetchFromGitLab {
            owner = "virtio-fs";
            repo = "virtiofsd";
            rev = "47e1f31ec9e5dbc8f2a0fec98f2b88cf1ef81369";
            hash = "sha256-3UJafKMuHWPPGjl308nXee3DzTcUhKr0RqRcbmUODCU=";
          };
          cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
            inherit src;
            hash = "sha256-2T2ky5h7N5VUga2Dcckhx0mXauFcMsz95fumrppnMH8=";
          };
        }))
      ];
      # looking-glass
      verbatimConfig = ''
        namespaces = []
        cgroup_device_acl = [
          "/dev/null", "/dev/full", "/dev/zero",
          "/dev/random", "/dev/urandom",
          "/dev/ptmx", "/dev/kvm", "/dev/kqemu",
          "/dev/rtc","/dev/hpet", "/dev/vfio/vfio",
          "/dev/kvmfr0"
        ]
      '';
    };
  };

  users.users.osi.extraGroups = ["libvirtd" "kvm"];
  environment.systemPackages = with pkgs; [
    virt-manager
    looking-glass-client
  ];

  # looking glass
  boot.extraModulePackages = [config.boot.kernelPackages.kvmfr];

  services.udev.customRules = [
    {
      name = "70-kvmfr";
      rules = ''
        SUBSYSTEM=="kvmfr", GROUP="kvm", MODE="0660", TAG+="uaccess"
      '';
    }
  ];
}
