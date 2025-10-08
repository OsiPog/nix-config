# Evaluates all NixOS configurations and updates the .sops.yaml file based on which secret files are used in which hosts
export def "main refresh-sops-files" [
  --flake: string = "/home/osi/nix-config"
  --sops-config: string = ".sops.yaml"
] {

  # Parse the nix flake to get the necessary data hosts secrets and their relations
  ^git add . # also new files should be evaluated
  let data = (^nix eval
    --impure
    --json
    --extra-experimental-features pipe-operators
    --expr $"
      __getFlake \"($flake)\"
      |> __getAttr \"nixosConfigurations\"
      |> __attrValues
      |> map \(host: {
        inherit \(host.config.networking\) hostName;
        inherit \(host.config.network.hosts.${host.config.networking.hostName}.ssh\) publicKey;
        inherit \(host.config.sops\) secrets;
      }\)
    ")
    | from json

  # Store host data with hostname and public age key
  let hosts = $data | each {{
    name: $in.hostName
    pubAgeKey: ($in.publicKey | ^ssh-to-age)
  }}

  # Find out how the secrets looked before that we can check which files need to be re-encrypted
  let secrets_before = open $"($flake)/($sops_config)"
    | get creation_rules
    | each {|$secret|{
      file: ($secret.path_regex | split row "$" | first)
      hosts: ($hosts
        | where {|$host| $host.pubAgeKey in ($secret | get key_groups.age | flatten | flatten)}
        | get name
        | sort
      )
    }}

  # Create a list of secrets containing the filename of the secret and all hosts that use the secret
  let secrets = $data
    | each {get secrets | values}
    | flatten
    | uniq-by "sopsFile"
    | each {|$secret|
      let currentHosts = ($data
        | get hostName
        | where {|$hostName|
            $secret.sopsFile in ($data | where {$in.hostName == $hostName} | get secrets | values | flatten | get sopsFile)}
        | sort
      )
      let file = ($secret.sopsFile | split row "/" | skip 4 | str join "/")
      let prev_version = $secrets_before | where {$in.file == $file} | if (($in | length) > 0) {$in | first} else {null}
      return {
        file: $file
        hosts: $currentHosts 
        changed: (($prev_version != null) and ($prev_version.hosts != $currentHosts))
        new: ($prev_version == null) 
      }
    }
    | sort-by file


  # Decrypt each secret temporarily in place as we are editing the creation rules
  $secrets | where {($in.changed or $in.new)} | each {|$secret| do {
    try {
      print $"decrypting ($secret.file)"
      ^sops --decrypt --in-place $"($flake)/($secret.file)"
    } catch {
      print $"failed decryption of ($secret.file), assuming already decrypted"
    }
  }}

  # Build a new .sops.yaml
  # we cannot use pure "to yaml" as this does not support variables and indentation
  {
    keys: ($data | each {$"&($in.hostName) ($in.publicKey | ^ssh-to-age)"})
    creation_rules: ($secrets | each {|$secret| {
      path_regex: $"($secret.file)$"
      key_groups: [{
        age: ($secret.hosts | each {$"*($in)"})
      }]
    }})
  }
  | to yaml
  # to make the variables work
  | str replace --all "'" ""
  | save $"($flake)/($sops_config)" --force

  # encrypting again with new config
  $secrets | where {(^cat $in.file) !~ "sops"} |  each {|$secret| do {
    try {
      print $"encrypting ($secret.file)"
      ^sops --encrypt --in-place $"($flake)/($secret.file)"
    } catch {
      # error is printed above
    }
  }}

  # needed so that the last loops return value is not printed
  return
}
