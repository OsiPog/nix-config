{
  pkgs,
  lib,
  config,
  ...
}: {
  programs.fish.plugins = lib.mkIf config.programs.fish.enable [
    # A nice theme
    {
      name = "theme";
      src = pkgs.fetchFromGitHub {
        owner = "oh-my-fish";
        repo = "theme-cbjohnson";
        rev = "6b5ddf3f332bd4eaebe3d57fc1a1f41dc8423bd2";
        sha256 = "sha256-uTqMTJIVcJ5XEEpcBZKIS059T0OSXdZl0sUPSA0iqa4=";
      };
    }
  ];
}
