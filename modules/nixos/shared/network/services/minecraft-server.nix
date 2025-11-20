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
    (mkServiceOptionsModule serviceName {
      portsDefault = {
        game.port = 25565;
        bedrock.port = 19132;
      };
    })
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
          white-list = true;
          spawn-protection = 0;
          enforce-secure-profile = false;
        };
        operators = {
          OsiBluber = "10d6960e-0f45-486c-804a-d0f98f0fedd0";
        };
        package = pkgs.minecraftServers.paper-1_21_10;
        symlinks = {
          # --- Plugins
          # Geyser, allow Bedrock players to connect to java server
          "plugins/Geyser-Spigot.jar" = fetchurl {
            url = "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot";
            hash = "sha256-rJcKRpLzkwEXZuHg/JiOfFVNLWJNy1j11sgZc4I4UcA=";
          };
          # "plugins/Geyser-Spigot/config.yml".value = {
          #   bedrock.port = cfg.ports.bedrock.port;
          # };
          # better compatibility for bedrock players
          "plugins/floodgate-spigot.jar" = fetchurl {
            url = "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot";
            hash = "sha256-c5N3B5s2L67M9dFvMUK6A0CphupISzcPIOymngWBDrY=";
          };
        };
      };
    };
  };
}
