{
  pkgs,
  lib,
  config,
  ...
}: {
  programs.fish.plugins = lib.mkIf config.programs.fish.enable [
    # A nice theme
    {
      name = "eclm";
      src = pkgs.fetchFromGitHub {
        owner = "oh-my-fish";
        repo = "theme-eclm";
        rev = "185c84a41947142d75c68da9bc6c59bcd32757e7";
        sha256 = "sha256-OBku4wwMROu3HQXkaM26qhL0SIEtz8ShypuLcpbxp78=";
      };
    }
  ];
}
