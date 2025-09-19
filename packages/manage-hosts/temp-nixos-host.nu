use std/assert

const SERVER_TYPE = {
  "x86": "ccx33" # cx22, ccx33
  "arm64": "cax41" # cax11, cax41
}

export def create-temp-nixos-host [arch: string] {
  assert ($arch in ["x86" "arm64"])

  open ".env" | from toml | load-env

  # Create the hetzner server
  print $"Creating ($arch)-server..."
  let server = api /servers {
    name: $"temp-($arch)",
    server_type: ($SERVER_TYPE | get $arch),
    location: "fsn1",
    image: "debian-13",
    ssh_keys: ["root@biome-fest"],
  } | get server

  let ipAddress = $server | get public_net.ipv4.ip;

  ssh-keygen -R $ipAddress

  print $"Created server with id: ($server.id)"

  while true {
    sleep 500ms
    try {
      ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 $"root@($ipAddress)" echo
      if ($env.LAST_EXIT_CODE == 0) {
        break;
      }
    }
    print "Server is not yet running, checking again in 5 seconds..."
  }

  print "Installing Nix..."

  # Trust the host in ssh

  # install nix
  # make sure that sshd_config contains SetEnv PATH=/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  ssh $"root@($ipAddress)" bash -c "echo 'n' | sh <(curl --proto \'=https\' --tlsv1.2 -L https://nixos.org/nix/install) --daemon"

  # make ssh set correct path variable
  ssh $"root@($ipAddress)" "
    echo 'SetEnv PATH=/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' >> /etc/ssh/sshd_config
    systemctl restart sshd
  "

  return $ipAddress

  def api --env [route: string, body: record = {}] {
    let headers = {
      "Authorization": $"Bearer ($env.HETZNER_API_KEY)"
    };
    let route = "https://api.hetzner.cloud/v1" + $route

    if ($body == {}) {
      return (http get --headers $headers $route)
    } else {
      return (http post --headers $headers $route ($body | to json))
    }
  }
}
