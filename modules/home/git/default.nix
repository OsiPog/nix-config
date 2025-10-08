{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (builtins) listToAttrs concatStringsSep;
  inherit (lib) pipe flatten concatLines;

  authorKeys = [
    "primary"
    "secondary"
  ];
in {
  home.packages = with pkgs; [
    lazygit
    (writeShellApplication {
      name = "git-set-author";
      runtimeInputs = with pkgs; [
        git
        fzf
        jq
      ];
      text = ''
        declare -A names
        ${pipe authorKeys [
          (map (author: ''names["${author}"]=$(cat ${config.getSopsFile "git-authors/${author}/name"})''))
          concatLines
        ]}
        declare -A emails
        ${pipe authorKeys [
          (map (author: ''emails["${author}"]=$(cat ${config.getSopsFile "git-authors/${author}/email"})''))
          concatLines
        ]}

        author=$(echo -e "${
          pipe authorKeys [
            (map (author: "${author} - \${names['${author}']}"))
            (concatStringsSep "\\n")
          ]
        }" | fzf | awk '{print $1}')

        git config user.name "''${names["$author"]}"
        git config user.email "''${emails["$author"]}"
      '';
    })
  ];

  sops.secrets =
    {
      "ssh-keys/gh-primary/private" = {};
      "ssh-keys/gh-secondary/private" = {};
    }
    // (pipe authorKeys [
      (map (author: [
        {
          name = "git-authors/${author}/name";
          value = {sopsFile = ./secrets.yaml;};
        }
        {
          name = "git-authors/${author}/email";
          value = {sopsFile = ./secrets.yaml;};
        }
      ]))
      flatten
      listToAttrs
    ]);

  programs.git = {
    enable = true;
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  # nice cli git experience
  programs.lazygit = {
    enable = true;
    settings = {
      mouseEvents = false; # don't need no mouse
    };
  };

  # github cli
  programs.gh.enable = true;
  programs.ssh = {
    # GitHub SSH config
    matchBlocks = {
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = config.getSopsFile "ssh-keys/gh-primary/private";
        identitiesOnly = true;
      };
      "secondary.github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = config.getSopsFile "ssh-keys/gh-secondary/private";
        identitiesOnly = true;
      };
    };
  };
}
