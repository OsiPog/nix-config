{...}: {
  vpn.ip = "100.64.0.2";
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDIcVpuDI9fFcNWeMEHelbaItqQJwmAkibSFR+nBhxng root@biome-fest";
    allowConnectionsFrom = ["dead-voxel"];
  };
  # services.syncthing = {
  #   enable = true;
  #   settings = {
  #     id = "SGSXHMI-OZGR23Y-4MO3YJZ-LW25XIP-R7LD52C-RGGEUYR-SKYDJLV-S253WAG";
  #     sharedFolders = {
  #       "working-files" = "/home/osi/files";
  #       "prism-launcher" = "/home/osi/.local/share/PrismLauncher";
  #     };
  #   };
  # };
}
