def main [ ssh_key_dir: string = /etc/ssh age_keys_file: string = /root/.config/sops/age/keys.txt ] { 
    if (^bash -c 'echo $EUID') != "0" {error make { msg: "This command must be run as sudo." }}

    ls $ssh_key_dir
        # only filenames
        | get name
        | where {(open $in) =~ "OPENSSH PRIVATE KEY"}
        # choose only ed25519
        | where {|filename|
            "ssh-ed25519" == (
                ^ssh-keygen -y -f $filename
                    | split row " "
                    | first
            )
        }
        | each {^ssh-to-age -private-key -i $in}
        | str join "\n"
        | save $age_keys_file --force
}
