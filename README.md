# NixOS Config

This is the NixOS flake which defines the system on all of my devices running NixOS. If you want to use this config yourself then I must disappoint you. It will fail because you'll need my SSH keys for them.

## Documentation

### Hosts

- `biome-fest` - My main laptop
  - Hyprland
  - acts as my workstation until I actually have one

- `haunt-muskie` - Small Hetzner VPS
  - that's where https://axelhax.net points to
  - reverse proxy for all services on the domain
  - Headscale server

- `wet-hands` - Steam Deck OLED
  - NixOS with the SteamOS interface

- `dead-voxel` - Gaming PC
  - Hyprland
  - AMD Radeon RX 9060 XT with AMD Ryzen 3600

- `floating-trees` - Home Server
  - runs all services
  - backup server for all other hosts

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
