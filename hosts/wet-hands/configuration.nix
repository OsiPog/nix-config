{
  flake,
  pkgs,
  lib,
  config,
  ...
}: {
  imports = with flake.nixosModules; [
    ./hardware-configuration.nix
    shared

    disko-basic

    steamos

    theme-prismarine
  ];

  disko.devices.disk.disk1.device = "/dev/nvme0n1";

  jovian = {
    devices.steamdeck.enable = true;
  };

  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/evenok-dark.yaml";
  stylix.image = config.lib.stylix.pixel "base00";

  home-manager.users.steam = {
    programs.kodi = {
      enable = true;
      package = pkgs.kodi-wayland.withPackages (kodiPkgs:
        with kodiPkgs; [
          jellyfin
          (kodiPkgs.buildKodiBinaryAddon rec {
            pname = "pvr.magenta";
            version = "21.8.0-Omega";

            src = pkgs.fetchFromGitHub {
              owner = "nirvana-7777";
              repo = pname;
              inherit version;
              sha256 = lib.fakeHash;
            };
          })
        ]);
    };
  };

  system.stateVersion = "25.11";
}
