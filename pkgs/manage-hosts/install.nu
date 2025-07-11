# Install a nixos configuration with nixos-anywhere to a remote host.
export def --wrapped "main install" [hostname: string --target_host: string ...rest: string] {
    ^nixos-anywhere --flake $".#($hostname)" --generate-hardware-config nixos-facter $"./hosts/($hostname)/facter.json" --target-host $target_host ...$rest
}