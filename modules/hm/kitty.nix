{pkgs, ...}: {
  programs.kitty = {
    enable = true;
    settings = {
      enable_audio_bell = "no";
      allow_remote_control = "yes";
    };
    extraConfig = ''
      map ctrl+shift+t new_tab_with_cwd

      # Thanks a lot to https://github.com/kovidgoyal/kitty-fosshack2024/issues/1
      map ctrl+shift+e launch --type=overlay --allow-remote-control ${pkgs.writeShellScript "" ''

        # Get all tabs, including their ids and focused status
        tab_info=$(kitty @ ls | ${pkgs.jq}/bin/jq -r '.[].tabs[] | "\(.id)|\(.is_focused)|\(.title)"')

        # Filter out the focused tab and prepare the list for fzf
        # Format: "last_directory (id: tab_id) | full_path | tab_id"
        tab_titles=$(echo "$tab_info" | awk -F'|' '$2 == "false" {
            print $1 " | " $3
        }')

        # Use fzf to fuzzy search the tab titles
        selected=$(echo "$tab_titles" | ${pkgs.fzf}/bin/fzf --prompt="Select tab: " \
            --height=60% \
            --layout=reverse \
            --border=rounded \
            --margin=10%,10% \
            --padding=1)

        # If a tab was selected, focus on that tab using its ID
        if [ -n "$selected" ]; then
            tab_id=$(echo "$selected" | awk '{print $1}')
            kitty @ focus-tab --match id:"$tab_id"
        else
            echo "No tab selected or operation cancelled."
        fi
      ''}
    '';
  };
}
