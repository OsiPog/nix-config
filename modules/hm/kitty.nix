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
      map ctrl+shift+e launch --type=overlay --allow-remote-control ${pkgs.writeShellScript "kitty-tab-switcher" ''

        # Get all tabs, including their ids and focused status
        tab_info=$(kitty @ ls | ${pkgs.jq}/bin/jq -r '.[].tabs[] | "\(.title)|\(.id)|\(.is_focused)"')

        # Filter out the focused tab and prepare the list for fzf
        tab_titles=$(echo "$tab_info" | sort | awk -F'|' '$3 == "false" {
            print $2 " | " $1
        }')

        # Use fzf to fuzzy search the tab titles
        selected=$(echo "$tab_titles" | ${pkgs.fzf}/bin/fzf \
            --prompt="Select tab: " \
            --height=60% \
            --layout=reverse \
            --border=rounded \
            --preview-window=down,50% \
            --preview=${pkgs.writeShellScript "" ''
              kitty @ launch \
                --source-window=$(echo "$@" | awk '{print $1}') \
                --stdin-source=@screen \
                --stdin-add-formatting \
                tee /tmp/fzf-preview \
                > /dev/null
              cat /tmp/fzf-preview
            ''})

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
