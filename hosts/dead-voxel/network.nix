{servicesById, ...}: {
  vpn.ip = "100.64.0.7";
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICoAlhl10PYwDxDLVhCZVru3AmAbGTdITdoGcrklDaTx root@dead-voxel";
    allowConnectionsFrom = ["biome-fest" "floating-trees"];
  };

  services.llamacpp.enable = true;
  ports.llamacpp.reverseProxy = {
    domain = "llm.axelhax.net";
    hidden = true;
  };

  services.librechat = {
    enable = true;
    require.openai-api = servicesById.llamacpp.provide.openai-api;
    require.oidc-server = servicesById.authelia.provide.oidc-server;
  };
  ports.librechat.reverseProxy.domain = "ai.axelhax.net";

  

  # services.backup = {
  #   enable = true;
  #   host = "floating-trees";
  # };
  # syncthing = {
  #   enable = true;
  #   id = "S3LC5E3-CAMYVL6-U6VGXUT-QMXKOZA-V3DVG5C-WMRQ52C-VTDC4GD-IVXRSAI";
  #   sharedFolders = {
  #     "working-files" = "/home/osi/files";
  #     "prism-launcher" = "/home/osi/.local/share/PrismLauncher";
  #     "ryujinx" = "/home/osi/.config/Ryujinx";
  #   };
  # };

  # services.nfs = {
  #   enable = true;
  #   mount.husk = "/husk";
  # };

  # ports.laravel-sail = {
  #   port = 8000;
  #   reverseProxy = {
  #     enable = true;
  #     domain = "axelhax.net";
  #     method = "stream";
  #   };
  # };
  # ports.laravel-sail-npm = {
  #   port = 5173;
  #   reverseProxy = {
  #     enable = true;
  #     domain = "axelhax.net";
  #     method = "stream";
  #   };
  # };
}
