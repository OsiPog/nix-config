{
  pkgs,
  lib,
  config,
  ...
}: let
  heygptWrapper = pkgs.writeShellApplication {
    name = "heygpt";
    text = ''
      OPENAI_API_BASE="https://api.openai.com/v1" \
      OPENAI_API_KEY=$(cat ${config.getSopsFile "api-keys/open-ai"}) \
      ${lib.getExe pkgs.heygpt} --model "''${HEYGPT_MODEL:-gpt-4o}" "$@"
    '';
  };
in {
  home.packages = with pkgs; [
    bluetuith # bluetooth tui
    devenv # dev environments made easy
    ncpamixer # Pulse Audio mixer utility
    restic
    nushell # a new and fancy type of shell
    opencommit # use AI to generate commit messages
    # Tools
    wl-clipboard-rs # copy to clipboard from terminal
    claude-code

    # Scripts
    heygptWrapper # terminal gpt integration
  ];

  # Secrets needed in this file
  sops.secrets = {
    "api-keys/open-ai" = {};
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
}
