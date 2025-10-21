{
  pkgs,
  config,
  ...
}: {
  home.packages = with pkgs; [
    lazygit
  ];

  programs.fish.functions.git-smart-clone =
    /*
    fish
    */
    ''
      nu ${./git-smart-clone.nu} --authors-json "$(cat ${config.getSopsFile "git-authors-json"})" $argv
      cd $(cat /tmp/git-smart-clone-cd)
    '';

  sops.secrets = {
    "ssh-keys/gh-primary/private" = {sopsFile = ./secrets.yaml;};
    "ssh-keys/gh-secondary/private" = {sopsFile = ./secrets.yaml;};
    "git-authors-json" = {sopsFile = ./secrets.yaml;};
  };

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
