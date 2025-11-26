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
      defaults = {
        ports = {
          java = {
            port = 25565;
            reverseProxy.method = "stream";
          };
          bedrock = {
            port = 19132;
            reverseProxy = {
              method = "stream";
              udp = true;
            };
          };
        };
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
      dataDir = cfg.stateDir;
      servers.default = {
        enable = true;
        serverProperties = {
          server-port = cfg.ports.java.port;
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
          # For modrinth downloads:
          # 1. go to versions page of plugin/mod
          # 2. select version and copy version id
          # 3. run `nix-modrinth-prefetch {version id}`
          #
          # Regarding Geyser download.geysermc.org downloads, version pinning is not perfect but its fine. (url still points to latest build)
          # To get all versions of a project query: https://download.geysermc.org/v2/projects/$PROJECT
          #
          #
          # Geyser, allow Bedrock players to connect to java server
          "plugins/Geyser-Spigot.jar" = fetchurl {
            url = "https://download.geysermc.org/v2/projects/geyser/versions/2.9.1/builds/latest/downloads/spigot";
            hash = "sha256-5f21qdfY2SZUDqknf1bGU846GGoSkzjDELmgsrvr2Rs=";
          };
          # Geyser likes to update its config, so this cannot be a symlink
          # "plugins/Geyser-Spigot/config.yml".value = {
          #   bedrock.port = cfg.ports.bedrock.port;
          # };
          # better compatibility for bedrock players
          "plugins/floodgate-spigot.jar" = fetchurl {
            url = "https://download.geysermc.org/v2/projects/floodgate/versions/2.2.5/builds/latest/downloads/spigot";
            hash = "sha256-c5N3B5s2L67M9dFvMUK6A0CphupISzcPIOymngWBDrY=";
          };
        };
      };
    };
  };
}
