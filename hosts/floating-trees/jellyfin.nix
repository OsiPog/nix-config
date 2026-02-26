{
  config,
  pkgs,
  ...
}: {
  # --- JELLYFIN
  # read husk
  users.users.jellyfin.extraGroups = ["husk" "render" "video"];
  fileSystems."${config.services.jellyfin.dataDir}/data/media" = {
    fsType = "fuse.bindfs";
    device = "/mnt/husk/media";
  };
  services.jellarr.config = {
    plugins = [{name = "bookshelf";}];
    library.virtualFolders = [
      {
        name = "Shows";
        collectionType = "tvshows";
        libraryOptions.pathInfos = [{path = "${config.services.jellyfin.dataDir}/data/media/Shows";}];
      }
      {
        name = "Books";
        collectionType = "books";
        libraryOptions.pathInfos = [{path = "${config.services.jellyfin.dataDir}/data/media/Books";}];
      }
    ];
  };
  # use hardware encoding
  services.jellarr.config.encoding = {
    enableHardwareEncoding = true;
    hardwareAccelerationType = "vaapi";
  };

  nixpkgs.config.allowUnfree = true;
}
