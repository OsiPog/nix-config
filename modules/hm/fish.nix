{
  pkgs,
  nixosConfig,
  lib,
  ...
}: {
  # terminal that makes me wet
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      ${pkgs.any-nix-shell}/bin/any-nix-shell fish --info-right | source
    '';
    shellAliases = {
      lg = "lazygit";
      c = "codium";
    };
    functions = {
      # --- NIX
      ns = "nix-shell -p $argv";
      nsc = "nix-shell -p $argv --command $argv";
      # rebuild = ''
      #   #!/bin/env fish

      #   # No VSCodium, these plugins are NOT obsolete!
      #   if test -f ~/.vscode-oss/extensions/.obsolete
      #     rm -f ~/.vscode-oss/extensions/.obsolete
      #   end

      #   # add all new files to git, so that they are seen by nixos
      #   set PREV_PWD "$PWD"
      #   cd ~/nixos
      #   direnv reload
      #   git add --all

      #   sudo nixos-rebuild --flake ~/nixos#${nixosConfig.hosts.this.name} $argv

      #   # only commit if succeeded
      #   if test $status -eq 0
      #     # commit all changes
      #     gptcommit
      #     git push
      #   end

      #   # Go back to previous cwd
      #   cd "$PREV_PWD"
      # '';

      # --- HEYGPT
      ask = ''
        if test (count $argv) -eq 0
          heygpt --stream
        else
          heygpt  """$argv""" | ${pkgs.glow}
        end
      '';
      # gptcommit = ''
      #   set message $(\
      #     heygpt \
      #       --system="You are a git commit generator. When given a certain diff you will reply with \
      #       ONLY ONE commit message following the conventional commits specification. Make sure to use scopes. \
      #       The allowed commit types are feat, fix, chore and refactor. \
      #       No Markdown, no codeblocks just a commit message. I REPEAT: No codeblocks and only allowed commit types \
      #       are feat, fix, chore and refactor!" \
      #       --temperature 0.1 \
      #       """$(git diff --staged)"""
      #   )

      #   git commit -m """$message"""
      # '';

      silent-plasma-restart = ''
        # restart plasmashell without any console output
        echo "Restarting KDE..."
        plasmashell --replace >/dev/null 2>1 &

        # detach from terminal
        disown
      '';
      ssh = "TERM=xterm-256color ${lib.getExe pkgs.openssh} $argv";
    };
  };
}
