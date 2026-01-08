{...}: {
  vpn.ip = "100.64.0.7";
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICoAlhl10PYwDxDLVhCZVru3AmAbGTdITdoGcrklDaTx root@dead-voxel";
    allowConnectionsFrom = ["biome-fest"];
  };
  stateDirs = ["/home/osi/files"];
  services = {
    backup = {
      enable = true;
      host = "floating-trees";
    };
    # syncthing = {
    #   enable = true;
    #   id = "S3LC5E3-CAMYVL6-U6VGXUT-QMXKOZA-V3DVG5C-WMRQ52C-VTDC4GD-IVXRSAI";
    #   sharedFolders = {
    #     "working-files" = "/home/osi/files";
    #     "prism-launcher" = "/home/osi/.local/share/PrismLauncher";
    #     "ryujinx" = "/home/osi/.config/Ryujinx";
    #   };
    # };
  };
}
