const HOSTNAMES = [
    "biome-fest",
    "blind-spots",
    "haunt-muskie",
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
# Creates an SSH key, appends a blank host config to `hosts.nix` and a secrets configurations in .sops.yaml
export def "main create" [ ip_address: string ] {
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

    let SSH_KEY_PATH = "/etc/ssh/id_ed25519_" + $NEW_HOSTNAME

    # At first we create a stub hardware configuration
    let hardware_config_path = "./hardware/" + $NEW_HOSTNAME + "/default.nix"
    mkdir (^dirname $hardware_config_path)

    if ($hardware_config_path | path exists) {
      print $"($hardware_config_path) exists, keeping"
    } else {
      $"{...}: {system.stateVersion = \"(^nixos-version | split row "." | take 2 | str join ".")\";}" | save $hardware_config_path
    }

    # generate a new ssh key
    ^sudo ssh-keygen -t ed25519 -f $SSH_KEY_PATH -N "" -C ("root@" + $NEW_HOSTNAME)
    # add age key to age keys file
    let privateAgeKey = ^sudo ssh-to-age -private-key -i $SSH_KEY_PATH
    ($privateAgeKey + "\n") | save --append /root/.config/sops/age/keys.txt

    # Then we append a new host to the hosts.nix file
    open ./hosts.nix
        | lines | take (($in | length) - 1) | str join "\n" # remove last line
        | ($in + $'
  ($NEW_HOSTNAME) = {
    ip-address = "($ip_address)";
    ssh = {
      public-key = "(^sudo ssh-keygen -y -f $SSH_KEY_PATH)";
      allow-connections-from = [ "(^hostname)" ];
    };
    nixos-modules = [
      "disko/basic"
    ];
  };
}
'       )
        | save hosts.nix --force
    # add new file rules to .sops.yaml
    ^cat .sops.yaml
        | str replace "creation_rules:" $"  - &($NEW_HOSTNAME) ($privateAgeKey | age-keygen -y)\ncreation_rules:"
        | do {
            $in + $"
  - path_regex: ($NEW_HOSTNAME).yaml$
    key_groups:
    - age:
      - *($NEW_HOSTNAME)
"       }
        | save .sops.yaml --force
}