# Shared Network Module

## Overview

Every NixOS host in this flake evaluates the same `network` module, which means each host can
see the configuration of every other host. This makes cross-host wiring (reverse proxy, backup,
LDAP clients, OIDC clients, …) fully declarative and type-checked.

Hosts opt in with `network.enable = true` (the default). A host with `network.enable = false`
still evaluates the module but contributes nothing to `network.hosts`.

---

## Top-level structure

```nix
network = {
  enable = true;           # set false to exclude this host
  sharedModules = [ … ];   # extra modules applied to every host's namespace

  hosts.<name> = {
    ssh.publicKey = "ssh-ed25519 …";
    ssh.allowConnectionsFrom = [ "haunt-muskie" ];  # list of host names

    domain = "axelhax.net";        # primary domain (sets networking.domain)
    extraDomains = [ "…" ];

    vpn.ip = "100.64.0.4";

    services.<serviceName> = { … };   # see Services below
  };
};
```

Each host defines its own slice in `hosts/<name>/network.nix`.

---

## Services

### Provide / Require

Every service has two mirrored namespaces:

- **`provide`** — what this service publishes for others to consume (`attrsOf submodule`).
- **`require`** — what this service expects to receive from others (`listOf submodule`).

Both are keyed by **interface name** (see [Interfaces](#interfaces) below).

```nix
services.authelia = {
  enable = true;

  # Publish an HTTP port and an OIDC server endpoint
  provide.ports.http = {
    port = 9091;
    proxy.domain = "auth.axelhax.net";
  };

  # Consume an LDAP server, a mail server, and OIDC clients
  require = (require "ldap-servers" { ids = [ "lldap" ]; })
         // (require "mail-servers" { ids = [ "snm" ]; })
         // (require "oidc-clients" { ids = [ "headscale" "opencloud" ]; });
};
```

The `require` helper (from `networkLib`) collects every matching `provide` entry from the listed
service IDs and returns them as a merged attrset of lists ready for assignment to
`services.<name>.require`.

### `getAddress`

Interface entries that represent a network endpoint expose a `getAddress` function:

```nix
getAddress :: template → string
```

The template string has placeholders substituted at evaluation time:

| Placeholder  | Substituted with                        |
|--------------|-----------------------------------------|
| `<domain>`   | The port/service's proxy domain         |
| `<host>`     | The host name the service runs on       |
| `<ip>`       | The VPN/tailnet IP of that host         |
| `<port>`     | The numeric port                        |
| `<protocol>` | The protocol string (e.g. `http`)       |

Examples:
```nix
port.getAddress "http://<host>:<port>"
ldapServer.getAddress "<protocol>://<domain>:<port>"
oidcServer.getAddress "https://<domain>"
```

---

## Defining services — `mkNetworkHostServiceModule`

`mkNetworkHostServiceModule` is the standard factory for network service modules. It lives in
`lib/flake/mkNetworkHostServiceModule.nix` and is available as `flake.lib.mkNetworkHostServiceModule`.

```nix
mkNetworkHostServiceModule
  { serviceName = "myservice";
    # enforceSingleInstance = false;  # error if more than one instance enabled (default: false)
  }
  ({ cfg, name, hostCfg, nixosConfig, … }: {
    # shorthand attributes transformed by the factory:
    optionsService = { … };   # → options.services.${serviceName} = { … }
    configEnable   = { … };   # → config = mkIf cfg.enable { … }
    configService  = { … };   # → config.services.${serviceName} = { … }
    provideEnable  = { … };   # → config.services.${serviceName}.provide = mkIf cfg.enable { … }

    # normal module attributes also work:
    options = { … };
    config  = { … };
  })
```

### Injected special args

| Arg           | Value                                       |
|---------------|---------------------------------------------|
| `cfg`         | `config.services.${serviceName}`            |
| `name`        | This host's name                            |
| `hostCfg`     | `network.hosts.${name}`                     |
| `nixosConfig` | The full NixOS config for this host         |

### Standard options added by the factory

Every service automatically gets:

- `services.${serviceName}.enable` — `mkEnableOption`
- `services.${serviceName}.id` — string (default = `serviceName`); decouple service identity from
  its module name when multiple instances are needed.
- `services.${serviceName}.provide.<interface>` — `attrsOf submodule` for each interface
- `services.${serviceName}.require.<interface>` — `listOf submodule` for each interface

---

## Network library helpers

Available as the `networkLib` special arg in host-level modules, and inside service modules as
`config.lib.network`.

### `require interfaceName { ids, extra? }`

Collects all `provide.<interfaceName>` entries from each service in `ids` and merges them into an
attrset of lists suitable for assignment to `services.<name>.require`:

```nix
{ networkLib, … }: let inherit (networkLib) require allServiceIds; in {
  services.backup = {
    require = require "backup-paths" {
      ids = allServiceIds;           # or a specific subset
      extra.zombie-horse-drive = {   # optional: inject entries not backed by a service
        host = "floating-trees";
        path = "/mnt/zombie-horse/cloud";
      };
    };
  };
}
```

### `allServiceIds`

List of every `id` across all enabled services on all hosts. Useful as the `ids` argument to
`require` when a service (like backup) should aggregate from everything.

### `getServiceVariables serviceName`

Convenience record for use inside a service file:

```nix
inherit (config.lib.network.getServiceVariables "authelia")
  serviceName   # "authelia"
  cfg           # config.services.authelia (on this host)
  stateDir      # "/var/lib/authelia"
  networkCfg    # config.network
  ;
```

---

## Interfaces

All interfaces are defined inside `mkNetworkHostServiceModule`. Each appears under both
`provide.<interface>` (attrsOf) and `require.<interface>` (listOf) on every service.

### `ports`

A network port/endpoint published by a service.

| Option              | Type                       | Default    | Description                                          |
|---------------------|----------------------------|------------|------------------------------------------------------|
| `port`              | `nullOr port`              | `null`     | TCP/UDP port number                                  |
| `protocol`          | `str`                      | —          | Application protocol (e.g. `"http"`, `"ldaps"`)      |
| `udp`               | `bool`                     | `false`    | Whether this is a UDP port                           |
| `host`              | `str`                      | host name  | Host the port lives on                               |
| `getAddress`        | `template → str`           | computed   | Interpolate `<domain>/<host>/<ip>/<port>/<protocol>` |
| `proxy.hidden`      | `bool`                     | `false`    | Not publicly reachable (LAN/tailnet only)            |
| `proxy.method`      | `"virtual-host"\|"stream"` | auto       | Reverse proxy method (auto-detected from domain)     |
| `proxy.domain`      | `nullOr str`               | `null`     | Virtual-host domain for TLS termination              |
| `proxy.extraConfig` | `attrs \| str`             | `{}`       | Merged into the nginx virtualHost or stream block    |

### `ldap-servers`

An LDAP directory server endpoint (provided by lldap).

| Option         | Description                                           |
|----------------|-------------------------------------------------------|
| `getAddress`   | Address function                                      |
| `baseDN`       | LDAP base distinguished name                          |
| `adminGroup`   | Group name for admin access                           |
| `secrets`      | Secret references                                     |
| `users.admin / search / manage` | Each has `dn`, `secretName`          |
| `attributes.email / uid / password / memberof / icon` | LDAP attribute names  |

### `ldap-clients`

LDAP client registration (provided by authelia, consumed by lldap).

| Option                | Description                                            |
|-----------------------|--------------------------------------------------------|
| `secrets`             | Secret references                                      |
| `groups`              | `attrsOf` group definitions                            |
| `users`               | `attrsOf` with `display`, `email`, `secretName`, `groups` |
| `extraUserAttributes` | Additional LDAP attributes                             |

### `mail-servers`

A mail server endpoint.

| Option       | Description      |
|--------------|------------------|
| `getAddress` | Address function |

### `mail-clients`

Mail account registration (provided by authelia for notification mail).

| Option                   | Description                         |
|--------------------------|-------------------------------------|
| `secrets`                | Secret references                   |
| `mailAccount.uid`        | Account username                    |
| `mailAccount.display`    | Display name                        |
| `mailAccount.email`      | Email address                       |
| `mailAccount.secretName` | Secret holding the password         |

### `oidc-servers`

An OIDC/OAuth2 provider endpoint (provided by authelia).

| Option       | Description                      |
|--------------|----------------------------------|
| `getAddress` | Address function                 |
| `adminGroup` | Group with admin access          |
| `name`       | Human-readable provider name     |

### `oidc-clients`

An application registered as an OIDC client (provided by apps, consumed by authelia).

| Option                | Default                        | Description                          |
|-----------------------|--------------------------------|--------------------------------------|
| `clientId`            | —                              | OAuth2 client ID                     |
| `clientName`          | —                              | Display name in the consent screen   |
| `hashedClientSecret`  | —                              | Bcrypt hash of the client secret     |
| `clientSecretName`    | —                              | Secret name holding the raw secret   |
| `redirectUris`        | —                              | Allowed redirect URIs                |
| `scopes`              | `["openid" "profile" "email"]` | Granted scopes                       |
| `allowedGroup`        | —                              | LDAP group required to log in        |
| `public`              | `false`                        | Public client (no secret required)   |
| `pkce.enabled`        | `false`                        | Require PKCE                         |
| `pkce.method`         | `"S256"`                       | PKCE method (`"plain"` or `"S256"`)  |
| `idTokenClaims`       | `{}`                           | Extra claims in the ID token         |
| `endpointAuthMethod`  | —                              | Token endpoint auth method           |
| `secrets`             | —                              | Secret references                    |

### `openai-apis`

An OpenAI-compatible API endpoint.

| Option             | Description                    |
|--------------------|--------------------------------|
| `url`              | Base URL of the API            |
| `displayName`      | Human-readable name            |
| `secrets`          | Secret references              |
| `apiKeySecretName` | Secret holding the API key     |

### `tailscale-servers`

A Headscale/Tailscale control server.

| Option              | Description                             |
|---------------------|-----------------------------------------|
| `getAddress`        | Address function                        |
| `ip4Space`          | CGNAT IP space (e.g. `100.64.0.0/10`)  |
| `authKeySecretName` | Secret holding the auth key             |
| `secrets`           | Secret references                       |

### `tailscale-clients`

A host enrolled in the tailnet.

| Option     | Description               |
|------------|---------------------------|
| `ip`       | Tailnet IP of this client |
| `magicDns` | MagicDNS hostname         |

### `dns-servers`

A DNS server endpoint.

| Option       | Description      |
|--------------|------------------|
| `getAddress` | Address function |

### `dns-overrides`

A DNS rewrite/override entry.

| Option     | Description                  |
|------------|------------------------------|
| `query`    | Domain to override           |
| `response` | IP or value to return        |

### `backup-paths`

A path to include in backups.

| Option | Default   | Description                  |
|--------|-----------|------------------------------|
| `host` | host name | Host where the path lives    |
| `path` | —         | Absolute filesystem path     |

---

## Writing a service module

All service modules live in `modules/nixos/shared/network/services/`. A minimal example:

```nix
# modules/nixos/shared/network/services/myapp/default.nix
{ config, lib, flake, ... }:
let
  inherit (lib) mkOption types mkDefault mkIf;
  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network.getServiceVariables "myapp") cfg stateDir;
in {
  imports = [
    (mkNetworkHostServiceModule { serviceName = "myapp"; } ({ cfg, name, ... }: {

      optionsService = {
        instanceName = mkOption { type = types.str; default = "main"; };
      };

      provideEnable = {
        # Declare the port; the host sets proxy.domain in its network.nix
        ports.http = {
          protocol = "http";
          port = 8080;
        };

        # Register as an OIDC client
        oidc-clients.myapp = {
          clientId = "myapp";
          clientName = "My App";
          hashedClientSecret = "$2b$…";
          redirectUris = [ (cfg.provide.ports.http.getAddress "https://<domain>/oidc/callback") ];
          allowedGroup = "lldap_users";
        };
      };
    }))
  ];

  config = mkIf (config.network.enable && cfg.enable) {
    services.myapp = {
      enable = true;
      port = cfg.provide.ports.http.port;
      oidcIssuer = (lib.head cfg.require.oidc-servers).getAddress "https://<domain>";
    };
  };
}
```

Register it in `modules/nixos/shared/network/default.nix` imports, then wire it up in the host's
`network.nix`:

```nix
# hosts/floating-trees/network.nix
{ networkLib, … }: let inherit (networkLib) require; in {
  # …
  services.myapp = {
    enable = true;
    provide.ports.http.proxy.domain = "myapp.axelhax.net";
    require = require "oidc-servers" { ids = [ "authelia" ]; };
  };
}
```
