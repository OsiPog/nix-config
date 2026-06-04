{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.jellarr.nixosModules.default
  ];
  # --- JELLYFIN
  # read husk
  users.users.jellyfin.extraGroups = ["husk" "render" "video"];
  fileSystems."${config.services.jellyfin.dataDir}/data/media" = {
    fsType = "fuse.bindfs";
    device = "/mnt/zombie-horse/media";
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
        name = "Movies";
        collectionType = "movies";
        libraryOptions.pathInfos = [{path = "${config.services.jellyfin.dataDir}/data/media/Movies";}];
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

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      mesa
      libva-utils
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };

  nixpkgs.config.allowUnfree = true;
}
