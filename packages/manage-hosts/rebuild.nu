use std/assert
use temp-nixos-host.nu *

# Apply the given `func` if `ok` is true and just pass the input if not
def maybe_apply [ ok: bool func: closure ] {
    if $ok { do $func $in } else { $in }
}

# A wrapper for nixos-rebuild with extra features which integrates into my hosts structure
export def --wrapped "main rebuild" [ 
    --host (-h): string
    --flake-path (-p): path
    --disable-git-commit
    --flake (-f): string
    --build-on (-b): string = "local"
    command?: string
    ...rest: string
] {
    assert ($host == null or $host in (ls hosts --short-names | where {$in.type == "dir"} | get name)) $"'($host)' is not a configured host from the hosts/ directory."
    assert ($build_on in ["local" "remote" "hetzner-x86" "hetzner-arm64"]) "--build-on must one of 'local', 'remote'"

    let flakePath = $flake_path | default ($env.HOME + "/nix-config")
    let previousPWD = $env.PWD
    let host = $host | default (^hostname)    

    # In case no command was specified do nothing
    if $command == null {
        ^nixos-rebuild --help
        exit
    }

    if not $disable_git_commit {
        cd $flakePath
        ^git add --all
        cd $previousPWD
    }

    let parameters = [ ]
    # Add target host when target is not current host (must be on the tailnet)
    | maybe_apply ($host != (^hostname)) {
        append ["--target-host" $"root@($host)"]
    }
    # Add build-host if not local
    | maybe_apply ($build_on != 'local') {
        append ["--build-host" $"root@($host)"]
    }
    # if the host is the current host we need sudo during the process
    | maybe_apply ($host == (^hostname)) {
        append ["--sudo" "--ask-sudo-password"]
    }
    # at the end add flake location with output, command and other extra options
    | append [
        "--use-substitutes"
        "--flake" ($flake | default $"($flakePath)#($host)")
        $command
    ]
    | append $rest

    ^nixos-rebuild ...$parameters

    # Commit changes when nothing failed        
    if not $disable_git_commit {
        cd $flakePath
        ^git commit -m "Successful Rebuild"
        ^git push
        cd $previousPWD
    }
}
