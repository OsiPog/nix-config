const HOSTNAMES = [
    "biome-fest",
    "haunt-muskie",
    "blind-spots",
    "dreiton",
    "aria-math",
    "taswell",
    "dead-voxel",
    "moog-city",
    "concrete-halls",
    "floating-trees",
    "wet-hands",
]

# Creates a new host.
export def "main create" [ ] {
    # --- DECIDE NEW HOSTNAME AND VPN IP ADDRESS
    let NEW_HOSTNAME = $HOSTNAMES 
        | where {|hostname| 
            ^nix flake show --quiet --quiet --json
                | from json
                | get "nixosConfigurations"
                | columns 
                | find $hostname 
                | is-empty
        }
        | first
    let NEW_IP_ADDRESS = ls hosts --short-names
      | where {$in.type == "dir"}
      | get name
      | each {|hostname| ^nix eval --json --file $"hosts/($hostname)/meta.nix" 
        | from json
        | get ip-address
      }
      | sort
      | last
      | do {
        let octets = $in | split row "."

        ($octets | take (($octets | length) - 1) | str join ".") + "." + (((($octets | last) | into int) + 1) | into string)        
      }
    let HOST_DIR = $"hosts/($NEW_HOSTNAME)"
    mkdir $HOST_DIR

    # --- GENERATE SSH KEY
    let SSH_KEY_PATH = "/etc/ssh/id_ed25519_" + $NEW_HOSTNAME
    # generate a new ssh key
    ^sudo ssh-keygen -t ed25519 -f $SSH_KEY_PATH -N "" -C ("root@" + $NEW_HOSTNAME)
    # add age key to age keys file
    let privateAgeKey = ^sudo ssh-to-age -private-key -i $SSH_KEY_PATH
    ($privateAgeKey + "\n") | sudo tee --append /root/.config/sops/age/keys.txt

    # --- ADD RULE TO .SOPS.YAML
    ^cat .sops.yaml
        | str replace "creation_rules:" $"  - &($NEW_HOSTNAME) ($privateAgeKey | age-keygen -y)\ncreation_rules:"
        | do {
            $in + $"
  - path_regex: ^($HOST_DIR)/secrets.yaml$
    key_groups:
    - age:
      - *($NEW_HOSTNAME)\n"       }
        | save .sops.yaml --force

    # --- ADD ROOT PASSWORD TO SECRETS FILE
    let ROOT_PASS = (^pwgen -s 16 1)
    print $"The root password is: ($ROOT_PASS)"
    {"pass-hashes": {"root": $ROOT_PASS}} | to yaml
      | ^sudo sops encrypt --filename-override $"($HOST_DIR)/secrets.yaml"
      | save $"($HOST_DIR)/secrets.yaml"

    # --- CREATE NIX FILES FROM TEMPLATES
    {
      stateVersion: (^nixos-version | split row "." | take 2 | str join "."),
    }
    | to yaml 
    | ^mustache $"($env.FILE_PWD)/templates/configuration.nix.mustache"
    | save $"($HOST_DIR)/configuration.nix"
    
    {
      ipAddress: $NEW_IP_ADDRESS,
      sshPublicKey: (^sudo ssh-keygen -y -f $SSH_KEY_PATH),
      allowedConnectionHostname: (^hostname),
    }
    | to yaml
    | ^mustache $"($env.FILE_PWD)/templates/meta.nix.mustache"
    | save $"($HOST_DIR)/meta.nix"
}