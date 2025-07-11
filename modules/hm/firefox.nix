{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
  packageName = "librewolf";
  addons = inputs.nix-firefox-addons.addons.${pkgs.system};
in {
  # Make firefox default
  xdg.mimeApps.defaultApplications = lib.attrsets.genAttrs [
    # Open links in firefox
    "x-scheme-handler/http"
    "x-scheme-handler/https"
    "x-scheme-handler/about"
    "x-scheme-handler/unknown"

    # Open PDF Files with firefox
    "application/pdf"
  ] (type: "${packageName}.desktop");
  home.sessionVariables.DEFAULT_BROWSER = lib.getExe config.programs.firefox.package;

  # Install firefox.
  programs.firefox = {
    enable = true;
    package = pkgs.${packageName};
    configPath =
      if packageName == "firefox"
      then ".mozilla/firefox"
      else ".librewolf";

    # Some installation-wide settings and extensions
    # https://mozilla.github.io/policy-templates/
    policies = {
      AppAutoUpdate = false; # Disable automatic application update
      BackgroundAppUpdate = false; # Disable automatic application update in the background, when the application is not running.
      Bookmarks = [
        {
          # to search nixpkgs and options
          Title = "MyNixOS";
          URL = "https://mynixos.com/";
        }
        {
          # to search nix functions
          Title = "Noogle";
          URL = "https://noogle.dev/";
        }
        {
          Title = "Spotify";
          # a short link to the login page of spotify
          URL = "https://accounts.spotify.com/en/login?allow_password=1&continue=https%3A%2F%2Fopen.spotify.com";
        }
        {
          Title = "DuckDuckGo";
          URL = "https://duckduckgo.com/";
        }
        {
          Title = "Syncthing Web GUI";
          URL = "http://127.0.0.1:8384/";
        }
        {
          Title = "Hyprland Wiki";
          URL = "https://wiki.hypr.land/";
        }
      ];
      Cookies = {
        Behavior = "reject-foreign";
      };
      DisableAccounts = true;
      DisableFirefoxAccounts = true; # Disable Firefox Sync
      DisableFirefoxScreenshots = true; # No screenshots
      DisableFirefoxStudies = true;
      DisableForgetButton = true; # Thing that can wipe history for X time, handled differently
      DisableFormHistory = true;
      DisablePasswordReveal = true;
      DisablePocket = true;
      DisableProfileImport = true; # Purity enforcement: Only allow nix-defined profiles
      DisableProfileRefresh = true; # Disable the Refresh Firefox button on about:support and support.mozilla.org
      DisableSetDesktopBackground = true; # Remove the “Set As Desktop Background…” menuitem when right clicking on an image, because Nix is the only thing that can manage the backgroud
      DisableTelemetry = true;
      DisplayMenuBar = "default-off";
      DisplayBookmarksToolbar = "never"; # alternatives: "always" or "newtab"
      DontCheckDefaultBrowser = true;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
        EmailTracking = true;
      };
      ExtensionUpdate = false; # disable extension update, updating only should happen through updating the links below
      ExtensionSettings = {
        # Time-to-Work
        "{c52a7349-0c5d-479d-9917-0155a0c58c0a}" = {
          install_url = "https://github.com/OsiPog/time-to-work/releases/download/v1.2.5/time-to-work-1.2.5.xpi";
          installation_mode = "force_installed";
        };
      };
      FirefoxHome = {
        TopSites = false;
        SponsoredTopSites = false;
        Highlights = false;
        Snippets = false;
        Pocket = false;
        SponsoredPocket = false;
        Locked = true; # only allow changing setting here
      };
      FirefoxSuggest = {
        WebSuggestions = false;
        SponsoredSuggestions = false;
        ImproveSuggest = false;
        Locked = true;
      };
      NewTabPage = false;
      NoDefaultBookmarks = true;
      OfferToSaveLogins = true;
      # Disable first run page
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      Permissions = {
        Location = {
          BlockNewRequests = true;
          Locked = true;
        };
        Notifications = {
          BlockNewRequests = true;
          Locked = true;
        };
        Autoplay = {
          Default = "block-audio-video";
          Locked = true;
        };
      };
      PostQuantumKeyAgreementEnabled = true;
      Preferences = {
        "browser.startup.homepage" = "";
        "browser.sessionstore.resume_from_crash" = false;
        "extensions.autoDisableScopes" = 0;
      };
      PromptForDownloadLocation = false;
      SanitizeOnShutdown = {
        Cache = true;
        Sessions = true;
        History = true;
        Locked = true;
      };
      SearchBar = "unified"; # alternative: "separate"
      SearchSuggestEnabled = false;
      ShowHomeButton = false;
      TranslateEnabled = false;
      UserMessaging = {
        ExtensionRecommendations = false;
        FeatureRecommendations = false;
        UrlbarInterventions = false;
        SkipOnboarding = false;
        MoreFromMozilla = false;
        FirefoxLabs = false;
        Locked = true;
      };
    };

    profiles.default = {
      extensions = {
        packages = with addons; [
          ublock-origin # adblock
          darkreader # dark mode for every website
          chameleon-ext # user agent spoofing
          vimium-ff # vim motions for browser
          vue-js-devtools-v6-legacy
          youtube-recommended-videos # unhook: unclutters youtube
        ];
        settings = {};
      };
    };
  };
}
