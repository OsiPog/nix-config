# This module makes syncing specific folders across hosts as easy as possible.
# All hosts can configure `syncthing.sharedFolders` in their `network.nix` which is a basic attrset which maps syncthing folder names to the local
# paths on the hosts.
# All hosts that have the same syncthing folder names configured are matched together and these folders are automatically
# shared between them via syncthing. Each host will sync its local folder path with all other hosts that have declared the same folder name.
#
# For each shared folder, a bind mount is created using fuse.bindfs to allow the syncthing service to access the folder.
# For folders under /home, the bind mount maps the folder owner to the syncthing user, ensuring proper permissions.
{
  lib,
  config,
  hostName,
  ...
}: let
  inherit (builtins) hasAttr attrNames;
  inherit (lib) mkIf pipe;
  inherit (lib.attrsets) mapAttrs' nameValuePair filterAttrs;
  inherit (lib.strings) hasPrefix splitString optionalString;
  inherit (lib.lists) elemAt;

  cfg = config.network;
  hostCfg = cfg.hosts.${hostName};
in {
  config = mkIf (cfg.enable && hostCfg.syncthing.enable) {
    services.syncthing = {
      enable = true;
      openDefaultPorts = true;
      settings = {
        devices = pipe cfg.hosts [
          (filterAttrs (name: host: host.syncthing.enable && name != hostName))
          (mapAttrs' (name: host:
            nameValuePair name {
              id = host.syncthing.id;
              autoAcceptFolders = true;
              addresses = [
                # works for tailscale magicdns
                "tcp://${name}:22000"
              ];
            }))
        ];
        folders = pipe hostCfg.syncthing.sharedFolders [
          (mapAttrs' (folderName: folder:
            nameValuePair folderName {
              path = "~" + folder;
              devices = pipe cfg.hosts [
                (filterAttrs (
                  name: host:
                    host.syncthing.enable
                    && (hasAttr folderName host.syncthing.sharedFolders)
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
        name = config.services.syncthing.dataDir + folder;
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
      hostCfg.syncthing.sharedFolders;
  };
}
