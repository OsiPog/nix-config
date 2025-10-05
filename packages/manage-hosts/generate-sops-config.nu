export def "main generate-sops-config" [
  --flake: string = "/home/osi/nix-config"
  --sops-config: string = ".sops.yaml"
] {

  # Parse the nix flake to get the necessary data hosts secrets and their relations
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

  # Create a list of secrets containing the filename of the secret and all hosts that use the secret
  let secrets = $data
    | each {get secrets | values}
    | flatten
    | uniq-by "sopsFile"
    | each {|$secret|{
      file: ($secret.sopsFile | split row "/" | skip 4 | str join "/")
      hosts: ($data
        | get hostName
        | where {|$hostName|
            $secret.sopsFile in ($data | where {$in.hostName == $hostName} | get secrets | values | flatten | get sopsFile)}
      )
    }}

  # Decrypt each secret temporarily in place as we are editing the creation rules
  $secrets | each {|$secret| do {
    print $"decrypting ($secret.file)"
    ^sops --decrypt --in-place $"($flake)/($secret.file)"
  }}

  # Build a new .sops.yaml
  # we cannot use pure "to yaml" as this does not support variables and indentation
  let sops_yaml = []
    | append "keys:"
    | append ($data | each {$"  - &($in.hostName) ($in.publicKey | ^ssh-to-age)"})
    | append "creation_rules:"
    | append ($secrets | each {|$secret| []
      | append [
        $"  - path_regex: ($secret.file)$"
        "    key_groups:"
        "    - age:"
      ]
      | append ($secret.hosts | each {$"      - *($in)"})
    })
    | flatten
    | str join "\n"
    | save $"($flake)/($sops_config)" --force

  # encrypting again with new file
  $secrets | each {|$secret| do {
    print $"encrypting ($secret.file)"
    ^sops --encrypt --in-place $"($flake)/($secret.file)"
  }}
}
