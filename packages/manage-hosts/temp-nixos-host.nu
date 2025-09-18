use std/assert

const SERVER_TYPE = {
  "x86": "cx22" # ccx33
  "arm64": "cax11" # cax41
}

export def temp-nixos-host [arch: string] {
  assert ($arch in ["x86" "arm64"])

  open ".env" | from toml | load-env

  # Create the hetzner server
  print $"Creating ($arch)-server..."
  let server = api /servers {
    name: $"temp-($arch)",
    server_type: ($SERVER_TYPE | get $arch),
    image: "debian-13",
    ssh_keys: ["root@biome-fest"],
  } | get server

  let ipAddress = $server | get public_net.ipv4.ip;

  print $"Created server with id: ($server.id)"

  while true {
    sleep 5sec
    if (((api $"/servers/($server.id)") | get server.status) == "running") {
      break;
    }
    print "Server is not yet running, checking again in 5 seconds..."
  }

  print "Installing Nix..."

  # Trust the host in ssh
  ssh-keygen -R $ipAddress

  # install nix
  # make sure that sshd_config contains SetEnv PATH=/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  ssh -o StrictHostKeyChecking=accept-new $"root@($ipAddress)" bash -c "echo 'n' | sh <(curl --proto \'=https\' --tlsv1.2 -L https://nixos.org/nix/install) --daemon"

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

temp-nixos-host "arm64"
