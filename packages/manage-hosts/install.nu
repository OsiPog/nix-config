# Install a nixos configuration with nixos-anywhere to a remote host.
export def --wrapped "main install" [hostname: string target_host: string ...rest: string] {
    git add .

    # prepare ssh keys
    let extraFilesDir = $"/tmp/($hostname)-extra-files"
    mkdir $extraFilesDir

    mkdir $"($extraFilesDir)/etc/ssh"
    ^sudo cp $"/etc/ssh/id_ed25519_($hostname)" $"($extraFilesDir)/etc/ssh/id_ed25519"

    let modifiedNixFile = "modules/nixos/shared/default.nix"
    let modifiedNixFileContent = ^cat $modifiedNixFile
    if ($modifiedNixFileContent !~ "sops.secrets") {
        $modifiedNixFileContent
            | lines
            | insert (($in | length) - 1) "sops.secrets = lib.mkForce {};"
            | save $modifiedNixFile --force
    }

    # Install on remote system with nixos anywhere, but without secrets because the system activation fails in the
    # installer
    (^sudo nixos-anywhere 
        "--flake" $".#($hostname)"
        "-i" "/etc/ssh/id_ed25519"
        "--generate-hardware-config" "nixos-generate-config" $"./hosts/($hostname)/hardware-configuration.nix" 
        "--target-host" $target_host 
        "--extra-files" $extraFilesDir 
        ...$rest
    )

    # revert change
    $modifiedNixFileContent | save $modifiedNixFile --force
    
    # Remove invalid entry from known_hosts
    ^sudo ssh-keygen -R ($target_host | split row "@" | last)

    # Rebuild on remote system with secrets
    $env.NIX_SSHOPTS = "-o StrictHostKeyChecking=no"
    (^sudo "-E" 
        "nixos-rebuild" "switch" 
        "--flake" $".#($hostname)" 
        "--target-host" $target_host
        "--build-host" $target_host
    )
}
