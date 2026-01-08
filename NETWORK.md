# Shared Network Module

## Structure

Every host can access the network configuration of each other host. This makes reverse proxy and backup possible in a NixOS way while still staying true to the module system.

The structure that every host can see is like that:

```nix
network = {
  enable = true; # NixOS hosts that should not participate in the network can set this to false
  hosts = {
    foo = {
      # meta attributes
      ssh.publicKey = "...";
      vpn.ip = "100.64....";
      # services that run on the host that profit from network capabilities
      services = {
        authelia = {
          enable = true;
          # ...
        };
      };
      # An attribute set of ports, example below
      # Should ideally be set by the service
      ports = {
        authelia = {
          port = 8000;
          # OR
          portRange = {
            from = 40000;
            to = 41000;
          };

          reverseProxy = {
            enable = true;

            method = "virtual-host";
            domain = "git.axelhax.net";
            # OR
            method = "stream";
          };
        };
      };
    };
  };
};

```

Each host has a `network.nix` file in its directory that is used define its own section.

## Services

### Service Definitions


To make option definitions as easy as possible the implementation is similar to Home Manager. The `network.sharedModules` takes a list of modules for the network host namespace. For example:

```nix
{...}: {
  network.sharedModules = [({...}: {
    options = {
      foo = mkOption { /* ... */ };
    };
    config = {
      ports.foo.port = 1234;
    };
  })];
}
```

This will define the option `network.hosts.<name>.foo` and the declare the port `network.hosts.<name>.ports.foo` to be `1234`.


#### `mkNetworkHostServiceModule`

With the above we can already create service options that each host can turn on or off. But having multiple services definitions means a lot of duplicated code. Many places in the codebase assume each service to have an `enable` option or the services most likely want to declare a used port (its a network service after all).
That's what `mkNetworkHostServiceModule` is for in the flake's lib. It takes an attrset with parameters needed for the service definition and a network module for additional configuration.

```nix
{...}: {
  imports = [(
    mkNetworkHostServiceModule {
      serviceName = "authelia";
      # withEnable = true; # is true by default
      # ...
    }
    ({
      cfg, # extra special argument, its a shorthand for `config.${serviceName}`
      ...
    }: {
      options = { /* define service specific options here */ };
      config = { /* default values, force values, port definitions */ };
      optionsService = { /* ... */ }; # shorthand for options.services.${serviceName} = {}
      configEnable = { /* ... */ }; # shorthand for config = mkIf (cfg.enable) {}
    })
  )]
}
```

#### Example Service

All service definitions should be in the `modules/nixos/shared/network/services` directory. With the above function a service can be defined like this:

```nix
{
  config,
  lib,
  flake,
  hostName,
  ...
}: let
  inherit (lib) mkMerge mkIf mkDefault;
  inherit (flake.lib) mkNetworkHostServiceModule;

  serviceName = "authelia";
  networkCfg = config.network;
  hostCfg = networkCfg.hosts.${hostName};
  cfg = hostCfg.services.${serviceName};
  ports = hostCfg.ports;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({cfg, ...}: {
      optionsService = {
        instanceName = mkOption { /* ... */ };
      };
      configEnable = {
        ports.authelia.port = mkDefault 8080;
      }
    }))
  ];

  config = (mkIf (networkCfg.enable && cfg.enable) {
    services.authelia.instances.${cfg.instanceName} = {
      enable = true;
      inherit (ports.${serviceName}) port;
      # ...
    };
  });
};
```

This makes it incredibly easy to define options for each host in `network.hosts` while still having the freedom of the NixOS module system.


### Special Services

#### Reverse Proxy

A port (`network.hosts.<name>.ports.<name>`) can be reverse proxied by a host that has the `reverseProxy` service enabled.

```nix
network.hosts = {
  foo = {
    # ...
    ports.gitea = {
      port = 1234;
      reverseProxy = {
        enable = true;
        domain = "git.example.com";
      };
    }
  };

  bar = {
    domain = "example.com";
    # ...
    services.reverseProxy.enable = true;
    # ...
  };
}
```

In this example the `bar` host will resolve `https://git.example.com` (the SSL certificate for TLS is created automatically) to `http://<ip address of foo>:1234`

Alternatively the `foo` host can set `ports.gitea.reverseProxy.method` equal to `"stream"` and `ports.gitea.reverseProxy.domain` to `"example.com"` then the `bar` host will directly reverse proxy the port via the nginx stream module and the `gitea` port will be accessable through `http://example.com:1234` (Note that the `gitea` service will need to handle TLS in that case if needed).
