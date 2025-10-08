use std/assert
use temp-nixos-host.nu *

# Apply the given `func` if `ok` is true and just pass the input if not
def maybe_apply [ ok: bool func: closure ] {
    if $ok { do $func $in } else { $in }
}

# A wrapper for nixos-rebuild with extra features which integrates into my hosts structure
export def --wrapped "main rebuild" [ 
    --host (-h): string # hostname in hosts/. Only should be used if the hosts is already in the tailnet.
    --flake-path (-p): path # path to the flake
    --disable-git-commit # whether to disable committing at the end
    --flake (-f): string # full nix flake expression e. g. ~/nixos#nixosConfig
    --build-on (-b): string = "auto" # 'local' (default) - builds on local machine, 'remote' - builds on remote machine, 'auto' - tries local build and if that fails tries remote build
    --interactive (-i) # Whether hosts should be chosen interactively
    command?: string # passed to nixos-rebuild e. g. `switch`
    ...rest: string
] {
    let flakePath = $flake_path | default ($env.HOME + "/nix-config")
    let previousPWD = $env.PWD
    let host = $host | default (^hostname)
    let nixosHosts = (^nix eval --impure --json --expr $"__attrNames \(__getFlake \"($flakePath)\"\).nixosConfigurations" | from json)

    assert ($host == null or $host in $nixosHosts) $"'($host)' is not a configured host from the hosts/ directory."
    assert ($build_on in ["local" "remote" "auto"]) "--build-on must one of 'local', 'remote', 'auto'"


    if not $disable_git_commit {
        cd $flakePath
        ^git add --all
        cd $previousPWD
    }

    # In case no command was specified do nothing
    if $command == null {
        ^nixos-rebuild --help
        exit
    }

    if (not $interactive) {
        let parameters = [ ]
        # Add target host when target is not current host (must be on the tailnet)
        | maybe_apply ($host != (^hostname)) {
            append ["--target-host" $"root@($host)"]
        }
        # Add build-host if not local
        | maybe_apply ($build_on == 'remote') {
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

        try {
            ^nixos-rebuild ...$parameters
        } catch {
            ^nixos-rebuild ...$parameters --build-host $"root@($host)"
        }
    } else {
        for $host in ($nixosHosts | input list --multi "Select host(s) to rebuild") {
            try {
                main rebuild $command --host $host --disable-git-commit
            } catch {
                # error shown above
            }
        }
    }

    # Commit changes when nothing failed        
    if not $disable_git_commit {
        lazygit
    }
}
