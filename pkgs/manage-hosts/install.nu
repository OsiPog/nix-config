# Install a nixos configuration with nixos-anywhere to a remote host.
export def --wrapped "main install" [hostname: string target_host: string ...rest: string] {
    git add .

    # prepare ssh keys
    let extraFilesDir = $"/tmp/($hostname)-extra-files"
    mkdir $extraFilesDir

    mkdir $"($extraFilesDir)/etc/ssh"
    sudo cp $"/etc/ssh/id_ed25519_($hostname)" $"($extraFilesDir)/etc/ssh/id_ed25519"

    ^sudo nixos-anywhere --flake $".#($hostname)" --generate-hardware-config nixos-facter $"./hosts/($hostname)/facter.json" --target-host $target_host --extra-files $extraFilesDir ...$rest

    sudo rm -rf $extraFilesDir
}