# Hosts

Here are all host-specific configurations stored as NixOS modules. Each host has its own directory containing the system configuration and metadata. The hosts are automatically discovered and made available as NixOS configurations in the flake outputs.

## Directory Structure

Each host directory contains:

- `default.nix` - The main NixOS module that imports system-wide modules using `self.nixosModules` and user configurations from `users/`
- `meta.nix` - Host metadata including IP address, SSH public key, and connection permissions
