const HOSTNAMES = [
    "biome-fest",
    "haunt-muskie",
    "dreiton",
    "blind-spots",
    "aria-math",
    "taswell",
    "dead-voxel",
    "moog-city",
    "concrete-halls",
    "floating-trees",
    "wet-hands",
]

# Creates a new host.
export def "main create" [ hostname: string ] {
    let HOST_DIR = $"hosts/($hostname)"
    mkdir $HOST_DIR

    # --- GENERATE SSH KEY
    let SSH_KEY_PATH = "/etc/ssh/id_ed25519_" + $hostname
    # generate a new ssh key
    ^sudo ssh-keygen -t ed25519 -f $SSH_KEY_PATH -N "" -C ("root@" + $hostname)
    # add age key to age keys file
    let privateAgeKey = ^sudo ssh-to-age -private-key -i $SSH_KEY_PATH
    ($privateAgeKey + "\n") | sudo tee --append /root/.config/sops/age/keys.txt

    # --- ADD RULE TO .SOPS.YAML
    ^cat .sops.yaml
        | str replace "creation_rules:" $"  - &($hostname) ($privateAgeKey | age-keygen -y)\ncreation_rules:"
        | do {
            $in + $"
  - path_regex: ^($HOST_DIR)/secrets.yaml$
    key_groups:
    - age:
      - *($hostname)\n"       }
        | save .sops.yaml --force

    # --- ADD LEAF PASSWORD TO SECRETS FILE
    let LEAF_PASS = (^pwgen -s 16 1)
    print $"The leaf password is: ($LEAF_PASS)"
    {
      "pass-hashes": {
        "leaf": ($LEAF_PASS | mkpasswd --stdin)
      }
      # this is just in case i forget it but still have the ssh key
      "pass-words": {
        "leaf": $LEAF_PASS,
      }
    } | to yaml
      | ^sudo sops encrypt --filename-override $"($HOST_DIR)/secrets.yaml"
      | save $"($HOST_DIR)/secrets.yaml" --force

    # --- CREATE NIX FILES FROM TEMPLATES
    print "Add the new host to network.nix:"
    {
      stateVersion: (^nixos-version | split row "." | take 2 | str join "."),
    }
    | to yaml 
    | ^mustache $"($env.FILE_PWD)/templates/configuration.nix.mustache"
    | save $"($HOST_DIR)/configuration.nix" --force
    
    {
      hostname: $hostname,
      sshPublicKey: (^sudo ssh-keygen -y -f $SSH_KEY_PATH),
      allowedConnectionHostname: (^hostname),
    }
    | to yaml
    | ^mustache $"($env.FILE_PWD)/templates/meta.nix.mustache"
}
