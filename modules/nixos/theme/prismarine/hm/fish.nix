{
  pkgs,
  lib,
  config,
  ...
}: {
  programs.fish.plugins = lib.mkIf config.programs.fish.enable [
    # A nice theme
    {
      name = "bobthefish";
      src = pkgs.fetchFromGitHub {
        owner = "oh-my-fish";
        repo = "theme-bobthefish";
        rev = "e3b4d4eafc23516e35f162686f08a42edf844e40";
        sha256 = "sha256-cXOYvdn74H4rkMWSC7G6bT4wa9d3/3vRnKed2ixRnuA=";
      };
    }
  ];
}
