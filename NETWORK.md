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

## Service Definitions

In `modules/nixos/shared/network/services` are the services defined that can be used in `network.hosts.<name>.services`. As these are not normal NixOS options be need to be replicated among all hosts.

For that the special lib function `mkNetworkHostModule`. A typical service definition looks like this


```nix
{
  config,
  lib,
  flake,
  hostName,
  ...
}: let
  inherit (lib) mkOption mkIf mkEnableOption;
  inherit (flake.lib) mkServiceOptionsModule;
  inherit (config.lib.network) toFullDomain;

  serviceName = "authelia";
  networkCfg = config.network;
  hostCfg = networkCfg.hosts.${hostName};
  cfg = hostCfg.services.${serviceName};
  ports = hostCfg.ports;
in {
  imports = [
    {
      network.sharedModules = [({...}: let
          cfg = config.services.${serviceName};
        in {
          options.services.${serviceName} = {
            enable = mkEnableOption "the ${serviceName} network service on ${hostName}."
            # ...
          };
          config = mkIf (cfg.enable) {
            ports.${serviceName}.port = mkDefault 8000;
            # ...
          };
        })]
    }
  ];

  
  # Actual implementation of the service
  # Use nixpkgs options here to define what the service does and where it defines what
  config = mkIf (networkCfg.enable && cfg.enable) {

    services.authelia.instances.default = {
      enable = true;
      inherit (ports.${serviceName}) port;
      # ...
    };

  };
}
```

This makes it incredibly easy to define options for each host in `network.hosts` while still having the freedom of the NixOS module system.
