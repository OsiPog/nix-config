# Network Integrations Refactor

## Current

Currently the services are half assed glued together in modules/nixos/shared/network/integrations with monolithic config declaring files.

Also, ports, damn ports. Port naming is global. Doing `getAddress {portName = "ldaps"}` will throw an error if the port is defined on multiple hosts.

## What's bad

Allowing a new service to be integrated is a lot of work. The integration file needs to be edited and understood how it worked again.

The implementation is very fixed on the master-service being integrated (in the case of lldap for example). This is not very object oriented and decoupled.
If I decide one day that a different ldap server should be used it's not plug and play at all.

The ports problem: The integrations should not have to run `getAddress {portName = "ldaps"}` themselves this should be exposed in some way that the correct hostName is already defined. If the service is running on multiple hosts this will fail!

## Ideas

### solving decoupling

- A `provide` attribute scoped inside each integration that can provide any data necessary to integrate the service into others
 - Provided data should be defined to have different formats. For example if one defines that the type of `provide` is `LDAP` then it should provide ldap values. This interface logic should help with decoupling the interfaces from their implementation.

- Then the relevant addresses can be provided via `provide`.

- Integrations should then be next to the service definitions. This can be done with a helper function so that there is not much duplicated code.

- I am thinking about something like this. from the `network.nix` side:


mailserver:
```nix
{...}: {
  services.mailserver = {
    integrations.ldap = {
      enable = true;
      role = "client";
      id = "lldap-main"; # client and server are matched by this id
    };
  };
}
```

lldap:
```nix
{...}: {
  services.lldap = {
    enable = true;
    integrations.ldap = {
      enable = true;
      role = "server";
      id = "lldap-main";
    };
  }
}

```

Then everything else can be defined inside the services:


master-service (`lldap`).
```nix
mkNetworkHostServiceModule {
  withIntegrations = ["ldap"]; # defines services.<serviceName>.integrations.ldap = {...} (see above)
}
{
  configService = {
    integrations.ldap.provide.server = {
      address = getAddress {...};
      searchUserDN = ...;
      userAttr = ...;
      ...
    };
  };
}
```

integrated service (`mailserver`)
```nix
mkNetworkHostServiceModule {
  withEnable = true;
  ...
  withIntegrations = ["ldap"];
} {
  configService = {
    integrations.ldap.provide.client = {
      group = "email";
    };
  };
};

...

config = {
  services.mailserver.ldap = mkIf (cfg.integrations.ldap.enable) (let
    inherit (cfg.integrations.ldap.require) server;
  in {
    url = server.address;
    user = server.userAttr;
    ...
  });
}

```

From the above you can see that both `provide` and `require` are scoped under `integrations.<integrationName>`. `provide` is what this service declares about itself, `require` is a computed property that resolves to the `provide` attrset of the matched peer. Matching is happening through the integration id and the integration name. `provide.server` is the `require.server` of the matched peer `provide.server` is the `require.server` of the matched peer. But `provide.clients` is a list of `require.client` of the matched peers.

What the example does not cover is the integration role `peer`. This is kind of integration where all peers have the same permissions. and `require.peers` resolves to each `provide.peer` even the own.
