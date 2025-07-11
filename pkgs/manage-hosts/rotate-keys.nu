# Rotates the SSH key (and with that also the AGE key of a specific host)
export def "main rotate-keys" [host?: string ssh_key_path: path = /etc/ssh/id_ed25519] {
    # make sure that the command is run as sudo
    if (^bash -c 'echo $EUID') != "0" {error make { msg: "This command must be run as sudo." }}

    # default to current host
    let hostname = $host | default (^hostname)
    let sshKeyPath = if ($host != null) {$ssh_key_path + "_" + $host} else {$ssh_key_path}

    # backup old ssh key
    cp $sshKeyPath ($sshKeyPath + "_" + (^ssh-keygen -y -f $sshKeyPath 
        | split row " " 
        | get 1 
        | str substring 0..8
    ))

    # generate new ssh key
    ^ssh-keygen -t ed25519 -f $sshKeyPath -N "" -C ("root@" + $hostname)

    # Replace public ssh key in hosts.nix
    open hosts.nix
        | str replace (
            ^nix eval --expr $"\(import ./hosts.nix\).($hostname).ssh.public-key" --impure
        ) $'"(^ssh-keygen -y -f $sshKeyPath)"'
        | save hosts.nix --force

    # add age key to age keys file
    let privateAgeKey = ^ssh-to-age -private-key -i $sshKeyPath
    ($privateAgeKey + "\n") | save --append /root/.config/sops/age/keys.txt

    # replace new public age key in .sops.yaml
    ^cat .sops.yaml
        | do {
            let prevPublicAge = $in 
                | lines
                | where {$in =~ "&" + $hostname}
                | first
                | split row " "
                | last

            $in | str replace $prevPublicAge ($privateAgeKey | ^age-keygen -y)
        }
        | save .sops.yaml --force
    
    ^sops updatekeys ("secrets/" + $hostname + ".yaml")
}