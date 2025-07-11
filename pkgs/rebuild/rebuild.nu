def --wrapped main [ 
    --hostname: string 
    --flake-path: path
    --disable-git-commit
    --flake: string
    command?: string
    ...rest: string
] {
    let flakePath = $flake_path | default ($env.HOME + "/nixos")
    let host = $hostname | default (^hostname)

    if $command == null {
        ^nixos-rebuild --help
        exit
    }

    let previousPWD = $env.PWD
    if not $disable_git_commit {
        cd $flakePath
        ^git add --all
        cd $previousPWD
    }

    (^sudo nixos-rebuild 
        --flake ($flake | default ($flakePath + "#" + $host)) 
        $command 
        ...$rest)
        
    if not $disable_git_commit {
        cd $flakePath
        ^git commit -m "Successful Rebuild"
        ^git push
        cd $previousPWD
    }
}
