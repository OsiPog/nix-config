{...}: {
  vpn.ip = "100.64.0.7";
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICoAlhl10PYwDxDLVhCZVru3AmAbGTdITdoGcrklDaTx root@dead-voxel";
    allowConnectionsFrom = ["biome-fest"];
  };
  # services = {
  #   backup = {
  #     enable = true;
  #     settings = {
  #       # TODO: this should be automatically handled by `serviceBackup` see the paths are defined in the service below
  #       paths = [
  #         "/home/osi/files"
  #         "/home/osi/.local/share/PrismLauncher"
  #         "/home/osi/.config/Ryujinx"
  #       ];
  #       host = "floating-trees";
  #     };
  #   };
  #   syncthing = {
  #     enable = true;
  #     settings = {
  #       id = "S3LC5E3-CAMYVL6-U6VGXUT-QMXKOZA-V3DVG5C-WMRQ52C-VTDC4GD-IVXRSAI";
  #       sharedFolders = {
  #         "working-files" = "/home/osi/files";
  #         "prism-launcher" = "/home/osi/.local/share/PrismLauncher";
  #         "ryujinx" = "/home/osi/.config/Ryujinx";
  #       };
  #     };
  #   };
  # };
}
