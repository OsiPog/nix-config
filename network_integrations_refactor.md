# Network Integrations Refactor

## Problem (Before)

- editing the integrations file, only one integration of a specific type
- very specialised code in `integrations`
- services are coupled intensely

- We need to create an interface logic where a service gets data in a specific format and implements it like the service needs it


## Solution: provide and require

We edit `mkNetworkHostServiceIntegrationModule` to include two new fields for each service. `provide` and `require`. Each have the same type. One is to provide data to other services the other is to require data from other services.

it may look like this:

```nix
# host 'vps', network.nix
{nixosConfig, ...}: {
  sevices.mailserver = {
    enable = true;
    require.ldap-server = nixosConfig.network.hosts.homeserver.services.portunus.provide.ldap-server;
  };
}
```

```nix
# host 'homeserver', network.nix
{nixosConfig, ...}: {
  sevices.portunus = {
    enable = true;
    require.ldap-clients = 
      nixosConfig.network.hosts.vps.services.mailserver.provide.ldap-clients
      // # ...
      # ...
  };
}
```
(of course we could use some kind of helper alias to make these config references shorter)

The respective services will set their `provide` attribute in their own service definitions. And implement the given require interface if set too.

The problem here is that when connecting two services we will need to change 2 code places at once. But that is semantically correct when thinking about nixos hosts, we have to rebuild 2 hosts, so changing 2 configs is just logically correct.


### The interfaces

#### `ldap-server`
- `secrets`
- `baseDN`, baseDN of ldap
- `address`, address to the server returned by getAddress
- `users`
  - `admin`, with `dn`, `secretName`, user with admin permissions
  - `search`, with `dn`, `secretName`, user with search permissions
  - `manage`, with `dn`, `secretName`, user with search and write permissions
- `attributes`, map of attribute names of the ldap server
  - `email`
  - `uid`
  - `password`
  - `memberof`
  - `icon`

#### `ldap-clients` (list of submodule)
- `secrets`
- `groups`, attrs of empty attrs of groups to create (attrname is group name)
- `users`, attrs of attrs (`display`, `email`, `secretName`) (attrname is uid)
- `extraUserAttributes`, attrs of user attributes (`dataType`, `editable`, `visible`, `multiple`) (attrname is user attribute name)


#### `mail-server`
- `address`

#### `mail-clients` (list of submodule)
- `secrets`
- `mailAccount`
  - `display`
  - `email`
  - `secretName`

#### `oidc-clients` (list of submodule)
- `redirectUri`
- `clientId`
- `clientSecretName`
- `scopes`
- ...

#### `oidc-server`
- `address`
- ...

## Port addressing

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

## shared secrets across services

When a secret is needed in a require/provide then a top-level secrets attrset is added. This one is meant to be imported into sops.secrets like so.

Then, to indicate what each provided secret is we use extra attributes that point to it:

```nix

# defined by a service
provide.ldap-server = {
  secrets = {
    "my-custom-integration/ldap-admin" = {/* ... */};
    # ...
  };
  adminSecretName = "my-custom-integration/ldap-admin";
}

# implementing

sops.secrets = cfg.require.ldap-server.secrets;

services.portunus.adminPassPath = config.getSopsFile cfg.require.ldap-server.adminSecretName;

```
