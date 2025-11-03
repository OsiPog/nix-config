def --wrapped main [url: string --base-dir: path = "~/repositories" --authors-json: string --get-directory ...rest] {
  let $authors = if ($authors_json != null) {
      $authors_json | from json
    } else {
      []
    }
    | each {insert "display" $"($in.name) - ($in.email)"}

  let directory = $url
    | str downcase
    | str replace "https://" ""
    | str replace "http://" ""
    | str replace "ssh://" ""
    | str replace --regex ".git$" ""
    | str replace --regex ":\\d+" "" # remove port from url
    | str replace --regex "(?:[a-z-]+\\.)*([a-z-]+\\.[a-z-]+[:/])" "$1" # shorten domain to just sld.tld
    # remove sshuser@ prefix
    | split row "@" | last | str join ""
    | str replace ":" "/"
    | do {($base_dir | str replace "~" $env.HOME) + "/" + $in}

  if ($get_directory) {
    print $directory
    pwd | save --force /tmp/git-smart-clone-cd
    return;
  }

  mkdir $directory

  git clone $url $directory ...$rest

  zoxide add $directory

  cd $directory
  $directory | save --force /tmp/git-smart-clone-cd # hack that we can cd into the new directory after calling `nu git-smart-clone.nu`

  # Ask the user which author
  if (($authors | length) > 0) {
    let author = $authors | input list "Select Author" --fuzzy --display display
    git config user.name $author.name
    git config user.email $author.email        
  }
}
