{...}: {
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICoAlhl10PYwDxDLVhCZVru3AmAbGTdITdoGcrklDaTx root@dead-voxel";
    allowConnectionsFrom = ["biome-fest"];
  };
  services.syncthing = {
    enable = true;
    settings = {
      id = "S3LC5E3-CAMYVL6-U6VGXUT-QMXKOZA-V3DVG5C-WMRQ52C-VTDC4GD-IVXRSAI";
      sharedFolders = {
        "working-files" = "/home/osi/files";
      };
    };
  };
}
