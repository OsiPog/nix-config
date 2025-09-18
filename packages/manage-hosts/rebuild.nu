# A wrapper for nixos-rebuild with extra features which integrates into my hosts structure
export def --wrapped "main rebuild" [ 
    --host (-h): string
    --flake-path (-p): path
    --disable-git-commit
    --flake (-f): string
    command?: string
    ...rest: string
] {
    let flakePath = $flake_path | default ($env.HOME + "/nixos")
    let host = $host | default (^hostname)

    # if $command == null {
    #     ^nixos-rebuild --help
    #     exit
    # }

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
