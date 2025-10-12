{
  config,
  hostName,
  lib,
  flake,
  inputs,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  inherit (flake.lib) mkServiceOptionsModule;

  cfg = config.network.services.minecraft-server;
in {
  imports = [
    (mkServiceOptionsModule "minecraft-server")
    inputs.nix-minecraft.nixosModules.minecraft-servers
  ];
  config = mkIf (cfg.enable && cfg.host == hostName) {
    nixpkgs.config.allowUnfree = true;

    nixpkgs.overlays = [inputs.nix-minecraft.overlay];

    services.minecraft-servers = {
      enable = true;
      eula = true;
      servers.default = {
        enable = true;
        serverProperties.server-port = cfg.port;
        package = pkgs.vanillaServers.vanilla-1_21_10;
      };
    };
  };
}
