# Network Integrations Refactor

## Problem (Before)

Services were glued together in `modules/nixos/shared/network/integrations` with monolithic config files. Adding a new integration required editing those files and re-learning how they worked.

Port naming was global — `getAddress {portName = "ldaps"}` would fail if the same port name existed on multiple hosts.

The integration structure was tightly coupled to specific service implementations (e.g. lldap specifically), making it hard to swap in a different LDAP server.

## Solution

### `network.integrations.<integrationName>.<id>`

Integrations are now a global registry keyed by integration type and ID:

```
network.integrations.ldap."lldap-main" = {
  server = { baseDN = ...; adminUser = ...; searchUserDN = ...; };
  clients = [ { group = "email"; } ... ];
};
```

Each integration type (ldap, oidc, mail) defines its schema in `modules/nixos/shared/network/integrations.nix` using `mkIntegration`:

```nix
ldap = mkIntegration {
  server = { baseDN = mkOption {...}; adminUser = mkOption {...}; ... };
  clients = { group = mkOption {...}; };
};
```

### Declaring integrations from `network.nix`

Each host declares which integrations its services participate in:

```nix
# lldap is the LDAP server
services.lldap = {
  enable = true;
  integrations.ldap = {
    enable = true;   # defaults to false
    id = "lldap-main";
  };
};

# authelia is an LDAP client
services.authelia = {
  enable = true;
  integrations.ldap = {
    enable = true;
    id = "lldap-main";  # same ID → matched to the same integration entry
  };
};
```

The `id` is what links clients to their server. Both point to `network.integrations.ldap."lldap-main"`.

### Populating data via `integrationsEnable`

Service modules use `integrationsEnable` inside `mkNetworkHostServiceModule` to register their data into the global registry. It is only active when `cfg.enable && cfg.integrations.<name>.enable`.

```nix
mkNetworkHostServiceModule {serviceName = "lldap";} ({name, ...}: {
  integrationsEnable = {
    ldap.server = {
      address = getAddress { portName = "ldaps"; hostName = name; };
      baseDN = "dc=axelhax,dc=net";
      searchUserDN = "uid=search,ou=people,dc=axelhax,dc=net";
    };
  };
})
```

This is mapped by `mkNetworkHostServiceModule` to:

```nix
config.integrations.ldap.${cfg._integrations.ldap.id} = mkIf (cfg.enable && cfg.integrations.ldap.enable) {
  server = { address = ...; baseDN = ...; searchUserDN = ...; };
};
```

### Consuming integration data

Service modules use `getServiceVariables` to get a resolved view where each integration name maps directly to the integration entry matched by the service's configured `id`:

```nix
inherit (getServiceVariables "authelia") cfg integrations;

# integrations.ldap = network.integrations.ldap.${cfg.integrations.ldap.id}
# e.g. = network.integrations.ldap."lldap-main"
```

So `integrations.ldap.server.baseDN` gives you the LDAP server's base DN without needing to know which specific service provides it.


### Port addressing

`getAddress` now always requires a `hostName`, scoping port lookups to a specific host:

```nix
getAddress {
  portName = "ldaps";
  hostName = name;  # the current host, passed in from mkNetworkHostServiceModule
}
```

The returned value is a template function:
- `address "domain"` → `"ldap.axelhax.net"` (if reverse proxied)
- `address "ip"` → VPN IP
- `address "host"` → `"localhost"` (if same host) or hostname

This solves the global port naming collision problem.

## TODO

I don't really know how to handle secrets yet.

Here are the specifications:

- less doubled code obviously
- register secrets into `sops.secrets`
- use unix groups for secrets so multiple services can access them on the same machine
- it should be defined in the integration interface which secrets are provided


Problems: if i have an `integrations.<name>.<id>.server.secrets` option then I cant use it in imports because it depends on config. But I somehow need a centralized way of "registering" secrets in a configuration (meaning setting `sops.secrets` and defining the groups the secrets mention, maybe even autmatically adding the right users to these groups.)
