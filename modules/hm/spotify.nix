{pkgs, ...}: {
  home.packages = with pkgs; [
    spotify-qt
  ];

  services.librespot = {
    enable = true;
  };

  programs.firefox.policies.Bookmarks = [
    {
      Title = "Spotify";
      # a short link to the login page of spotify
      URL = "https://accounts.spotify.com/en/login?allow_password=1&continue=https%3A%2F%2Fopen.spotify.com";
    }
  ];
}
