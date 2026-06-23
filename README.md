# NixOS Config

This is the NixOS flake which defines the system on all of my devices running NixOS. If you want to use this config yourself then I must disappoint you. It will fail because you'll need my SSH keys for them.

## Documentation

### Hosts

- `biome-fest` - My main laptop

- `haunt-muskie` - Small Hetzner VPS
  - that's where https://axelhax.net points to
  - reverse proxy for all services on the domain
  - Headscale server

- `wet-hands` - Steam Deck OLED
  - NixOS with the SteamOS interface

- `dead-voxel` - Gaming PC
  - Hyprland
  - AMD Radeon RX 9060 XT with AMD Ryzen 7 5700G

- `floating-trees` - Home Server
  - runs all services
  - backup server for all other hosts
  - jellyfin
  - Intel Arc A380

- `blind-spots` - External Backup Server (just an old laptop)
  - backup of the backup in a different geographical location

## Guides to remember

### Create NixOS installer

Replace `x86_64-linux` with any other system if needed.

```bash
nix build .#lib.x86_64-linux.installerIso
```

### Creating a new host

Here I use [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) to deploy new hosts anywhere.

1. `manage-hosts create <hostname>`
  - might need to change `disko.devices.disk.disk1.device` to something else than `"/dev/sda"` if needed
    - check with `lsblk` on the remote machine what's the default device name
  - don't forget to add host configuration to `network.nix` 

2. `manage-hosts install <hostname> root@<ip-address>`
  - this is what calls `nixos-anywhere`
  - add `--build-on remote` to build on remote machine


### Add OIDC to network service

1. Create client secret

```bash
nix run nixpkgs#authelia -- crypto hash generate pbkdf2 --variant sha512 --random --random.length 72 --random.charset rfc3986
```

2. Create `secrets.yaml` next to service (might need to move `services/<name>.nix` to `services/<name>/default.nix`)

Add the client secret there

3. Add `oidc-clients` provide (Open the OIDC guide of the service to find out what should be configured here)

```nix
provideEnable = {
  oidc-clients = [
    rec {
      secrets = mkSharedSecrets [clientSecretName] ./secrets.yaml;
      clientId = "<very unique client ID>";
      clientName = "<name visible in oidc prompt>";
      hashedClientSecret = "$pbkdf2-sha512$310000$OM....."; # the digest generated before
      clientSecretName = "<name>/oidc-secret";
      redirectUris = ["${ports.${portName}.address "proxyProtocol://domain"}/oidc/callback"];
      scopes = ["openid" "profile" "email" "groups"];
      pkce = {
        enabled = true;
        method = "S256";
      };
      idTokenClaims = ["email" "groups"];
    }
  ];
};
```

4. Add the provide to `services.authelia.require.oidc-clients` in `hosts/floating-trees/network.nix`, also the `oidc-server` provide to the require of your service

5. configure the service using their OIDC guide. Add a mkIf block into the mkMerge list like so:

```nix
config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
  {
    # usual config here
    # services.<name>.enable = true;
  }

  # ... other integrations

  # OIDC SERVER INTEGRATION
  (let
    oidcServer = cfg.require.oidc-server;
    oidcClient = head cfg.provide.oidc-clients;
    secrets = getAttrs [oidcClient.clientSecretName] oidcClient.secrets;
  in
    mkIf (oidcServer != null) {
      sops = {inherit secrets;};
      users.groups = mkGroupsFromSecretsWithMembers secrets [config.services.myService.user];
      services.myService.config.oidc = {
        # issuer = oidcServer.address "proxyProtocol://domain";
        # client_id = oidcClient.clientId;
        # client_secret_path = config.getSopsFile oidcClient.clientSecretName;
        # ....
      };
    })
]);
```

