{...}: {
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDIcVpuDI9fFcNWeMEHelbaItqQJwmAkibSFR+nBhxng root@biome-fest";
    allowConnectionsFrom = ["dead-voxel"];
  };
  syncthing = {
    enable = true;
    id = "SGSXHMI-OZGR23Y-4MO3YJZ-LW25XIP-R7LD52C-RGGEUYR-SKYDJLV-S253WAG";
    sharedFolders = {
      "working-files" = "/home/osi/files";
    };
  };
}
