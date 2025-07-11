# Users

Here are all user-specific configurations stored as NixOS modules and Home Manager configurations. Each user has their own directory containing both system-level user setup and home-manager configuration. Users are automatically made available as both NixOS modules and standalone Home Manager configurations in the flake outputs.

## Directory Structure

Each user directory contains:

- `default.nix` - NixOS module that sets up the user system-wide (user creation, system services, etc.)
- `home.nix` - Home Manager configuration that can be used standalone or imported by the NixOS module

## Usage

Users can be used in two ways:

1. **As part of host configurations**: Import the user's `default.nix` in a host configuration
2. **As standalone Home Manager configurations**: Available as `homeConfigurations` in flake outputs
