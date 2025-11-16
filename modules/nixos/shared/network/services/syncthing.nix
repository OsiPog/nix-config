# This module makes syncing specific folders across hosts as easy as possible.
# All hosts can configure `services.syncthing` in their `network.nix` with:
#   - id: The syncthing device ID for this host
#   - sharedFolders: A basic attrset which maps syncthing folder names to local paths
#
# All hosts that have the same syncthing folder names configured are matched together and these folders are automatically
# shared between them via syncthing. Each host will sync its local folder path with all other hosts that have declared the same folder name.
#
# For each shared folder, a bind mount is created using fuse.bindfs to allow the syncthing service to access the folder.
# For folders under /home, the bind mount maps the folder owner to the syncthing user, ensuring proper permissions.
{
  lib,
  config,
  hostName,
  flake,
  ...
}: let
  inherit (builtins) hasAttr attrNames;
  inherit (lib) mkIf pipe types mkOption;
  inherit (lib.attrsets) mapAttrs mapAttrs' filterAttrs;
  inherit (lib.strings) hasPrefix splitString optionalString;
  inherit (lib.lists) elemAt;
  inherit (flake.lib) mkServiceOptionsModule;

  serviceName = "syncthing";
  networkCfg = config.network;
  cfg = networkCfg.hosts.${hostName}.services.${serviceName};

  toMountPoint = path: "/mnt/sync/${path}";
in {
  imports = [
    (mkServiceOptionsModule serviceName {
      portsDefault = {
        web.port = 8384;
      };
      settingsOptions = {
        id = mkOption {
          type = types.str;
          description = "The syncthing device ID for this host.";
        };
        sharedFolders = mkOption {
          type = types.attrsOf types.str;
          default = {};
          description = ''
            Attrset mapping syncthing folder names to local paths on this host.
            Folders with matching names across hosts will be automatically synced.
          '';
        };
      };
    })
  ];

  config = mkIf (networkCfg.enable && cfg.enable) {
    services.syncthing = {
      enable = true;
      openDefaultPorts = true;
      guiAddress = "127.0.0.1:${toString cfg.ports.web.port}";
      settings = {
        devices = pipe networkCfg.hosts [
          (filterAttrs (name: host: host.services.${serviceName}.enable && name != hostName))
          (mapAttrs (name: host: {
            id = host.services.${serviceName}.settings.id;
            autoAcceptFolders = true;
            addresses = [
              # works for tailscale magicdns
              "tcp://${name}:22000"
            ];
          }))
        ];
        folders = pipe cfg.settings.sharedFolders [
          (mapAttrs (folderName: folder: {
            path = toMountPoint folder;
            devices = pipe networkCfg.hosts [
              (filterAttrs (
                name: host:
                  host.services.${serviceName}.enable
                  && (hasAttr folderName host.services.${serviceName}.settings.sharedFolders)
                  && name != hostName
              ))
              attrNames
            ];
          }))
        ];
      };
    };

    fileSystems =
      mapAttrs' (folderName: folder: {
        name = toMountPoint folder;
        value = {
          device = folder;
          fsType = "fuse.bindfs";
          options = optionalString (hasPrefix "/home" folder) (let
            folderOwner = elemAt (splitString "/" folder) 2;
            syncthingUser = config.services.syncthing.user;
          in [
            "map=${folderOwner}/${syncthingUser}"
          ]);
        };
      })
      cfg.settings.sharedFolders;
  };
}
