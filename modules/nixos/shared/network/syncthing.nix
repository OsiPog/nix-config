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
