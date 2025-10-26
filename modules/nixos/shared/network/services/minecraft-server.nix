{
  config,
  lib,
  flake,
  inputs,
  pkgs,
  hostName,
  ...
}: let
  inherit (lib) mkIf;
  inherit (flake.lib) mkServiceOptionsModule;
  inherit (pkgs) fetchurl;

  serviceName = "minecraft-server";
  networkCfg = config.network;
  cfg = networkCfg.hosts.${hostName}.services.${serviceName};
in {
  imports = [
    (mkServiceOptionsModule serviceName)
    inputs.nix-minecraft.nixosModules.minecraft-servers
  ];

  config = mkIf (networkCfg.enable && cfg.enable) {
    nixpkgs.config.allowUnfree = true;

    nixpkgs.overlays = [inputs.nix-minecraft.overlay];

    # needed to connect to minecraft server console
    # tmux -S /run/minecraft/default.sock attach (background again with: ctrl+b d)
    environment.systemPackages = [pkgs.tmux];

    services.minecraft-servers = {
      enable = true;
      eula = true;
      dataDir = "/var/minecraft";
      servers.default = {
        enable = true;
        serverProperties = {
          server-port = cfg.ports.game.port;
        };
        operators = {
          OsiBluber = "10d6960e-0f45-486c-804a-d0f98f0fedd0";
        };
        package = pkgs.minecraftServers.paper-1_21_10;
        symlinks = {
          # Plugins
          "plugins/Geyser-Spigot.jar" = fetchurl {
            url = "https://cdn.modrinth.com/data/wKkoqHrH/versions/TudMk9ax/Geyser-Spigot.jar";
            hash = "sha256-2lNPbrP1XTv1RTPVSVPyNefTgWF9EPgrUhU3Ms2Qktw=";
          };
          "plugins/Geyser-Spigot/config.yml".value = {
            bedrock.port = 19132;
          };
        };
      };
    };
  };
}
