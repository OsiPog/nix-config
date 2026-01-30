{
  pkgs,
  lib,
  config,
  ...
}: let
  heygptWrapper = pkgs.writeShellApplication {
    name = "heygpt";
    runtimeInputs = [pkgs.heygpt];
    text = ''
      OPENAI_API_BASE="https://api.openai.com/v1" \
      OPENAI_API_KEY=$(cat ${config.getSopsFile "api-keys/open-ai"}) \
      heygpt --model "''${HEYGPT_MODEL:-gpt-4o}" "$@"
    '';
  };
in {
  home.packages = with pkgs; [
    bluetuith # bluetooth tui
    devenv # dev environments made easy
    restic
    nushell # a new and fancy type of shell
    spotify-player # player for spotify
    # Tools
    wl-clipboard-rs # copy to clipboard from terminal
    serpl # global find and replace as tui
    # Scripts
    heygptWrapper # terminal gpt integration
    android-tools
  ];

  sops.secrets = {
    "api-keys/open-ai" = {
      sopsFile = ./secrets.yaml;
    };
    "api-keys/anthropic" = {
      sopsFile = ./secrets.yaml;
    };
  };

  # Mounting usb devices easily
  programs.bashmount.enable = true;

  # Youtube downloader
  programs.yt-dlp.enable = true;

  # for different environments based on .envrc in directory
  programs.direnv = {
    enable = true;
    silent = true;
    nix-direnv.enable = true;
  };

  # better cd
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  # better top
  programs.btop = {
    enable = true;
    settings = {
      # Using the theme provided by the terminal
      force_tty = "False";
    };
  };

  # better neofetch
  programs.fastfetch = {
    enable = true;
    settings = {
      logo.type = "kitty-icat";
      display = {
        separator = " -> ";
        color = {
          keys = "blue";
          title = "yellow";
        };
      };

      modules = [
        "break"
        "title"
        "separator"
        "os"
        "host"
        "kernel"
        "uptime"
        "packages"
        "shell"
        "display"
        "de"
        "wm"
        "theme"
        "terminal"
        "terminalfont"
        "cpu"
        "gpu"
        "memory"
        "swap"
        "disk"
        "localip"
        "battery"
        "poweradapter"
        "break"
        "colors"
      ];
    };
  };

  programs.claude-code = {
    enable = true;
    memory.text = ''
      Run any command that is not part of core linux with `nix run nixpkgs#<package-name>`
    '';
    settings = {
      apiKeyHelper = "cat " + (config.getSopsFile "api-keys/anthropic");
    };
  };
}
