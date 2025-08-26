{pkgs, ...}: {
  home.packages = with pkgs; [
    (writeShellApplication {
      name = "topydo";
      runtimeInputs = [topydo];
      text = ''
        topydo -t "$HOME"/files/local/written-mind/todo/todo.txt -d "$HOME"/files/local/written-mind/todo/done.txt "$@"
      '';
    })
  ];

  programs.fish = {
    interactiveShellInit = ''
      topydo ls -F "- %s" -g due | ${pkgs.glow}/bin/glow
    '';
    shellAliases.t = "topydo";
  };
}
