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
    --flake (-f): string # full nix flake expression e. g. ~/nixos#nixosConfig
    --build-on (-b): string = "auto" # 'local' (default) - builds on local machine, 'remote' - builds on remote machine, 'auto' - tries local build and if that fails tries remote build
    --interactive (-i) # Whether hosts should be chosen interactively
    command?: string # passed to nixos-rebuild e. g. `switch`
    ...rest: string
] {
    let flakePath = $flake_path | default (pwd)
    let previousPWD = $env.PWD
    let host = $host | default (^hostname)
    let nixosHosts = (^nix eval --impure --json --expr $"__attrNames \(__getFlake \"($flakePath)\"\).nixosConfigurations" | from json)

    assert ($host == null or $host in $nixosHosts) $"'($host)' is not a configured host from the hosts/ directory."
    assert ($build_on in ["local" "remote" "auto"]) "--build-on must one of 'local', 'remote', 'auto'"

    # To prevent any missing files errors
    cd $flakePath
    ^git add --all
    cd $previousPWD

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

        # 1. try to rebuild on current machine
        try {
            ^nixos-rebuild ...$parameters
        } catch {|$err|
            # 2. try rebuilding again on remote host on error and build_on = auto
            if ($env.LAST_EXIT_CODE == 1 and $build_on == 'auto' and $host != (^hostname)) {
                print "Build failed, trying again on remote host as build_on=auto..."
                ^nixos-rebuild ...$parameters --build-host $"root@($host)"
            } else {
                error make $err
            }
        }
    } else {
        let selectedHosts = ($nixosHosts | prepend "All" | input list --multi "Select host(s) to rebuild")
        for $host in (if ("All" in $selectedHosts) {$nixosHosts} else {$selectedHosts}) {
            try {
                # 1. try to connect if not self
                if ($host != (^hostname)) {
                    ^ssh -o ConnectTimeout=3 $"leaf@($host)" echo $"Connection to ($host) succeeded!"
                }
                # 2. now that we know connection is possible: rebuild
                main rebuild $command --host $host
            } catch {
                # error shown above
            }
        }
    }
}
