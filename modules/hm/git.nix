{
  pkgs,
  lib,
  config,
  nixosConfig,
  self,
  ...
}: let
  inherit (builtins) readFile getAttr listToAttrs concatStringsSep;
  inherit (lib) pipe attrsToList flatten concatLines;
  inherit (self.lib.${pkgs.system}) fromYAML;

  gitAuthorKeysFromSops = pipe nixosConfig.sops.defaultSopsFile [
    readFile
    fromYAML
    (sopsFile: sopsFile.git-authors or {})
    attrsToList
    (map (getAttr "name"))
  ];
in {
  home.packages = with pkgs; [
    lazygit
    (writeShellApplication {
      name = "git-set-author";
      runtimeInputs = with pkgs; [git fzf jq];
      text = let
      in ''
        declare -A names
        ${pipe gitAuthorKeysFromSops [
          (map (author: ''names["${author}"]=$(cat ${config.getSopsFile "git-authors/${author}/name"})''))
          concatLines
        ]}
        declare -A emails
        ${pipe gitAuthorKeysFromSops [
          (map (author: ''emails["${author}"]=$(cat ${config.getSopsFile "git-authors/${author}/email"})''))
          concatLines
        ]}

        author=$(echo -e "${
          pipe gitAuthorKeysFromSops [
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
    // (pipe gitAuthorKeysFromSops [
      (map (author: [
        {
          name = "git-authors/${author}/name";
          value = {};
        }
        {
          name = "git-authors/${author}/email";
          value = {};
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

  # GitHub SSH config
  programs.ssh.matchBlocks = {
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
}
