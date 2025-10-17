# nixos-config

This is the NixOS flake which defines the system on all of my devices running NixOS. If you want to use this config yourself then I must disappoint you. It will fail because you'll need my SSH keys for it

## Documentation

### Hosts

- `biome-fest` - My main laptop
  - Hyprland
  - acts as my workstation until I actually have one

- `haunt-muskie` - Small Hetzner VPS
  - thats where https://axelhax.net points to
  - reverse proxy for all services onto the domain
  - Headscale server

- `wet-hands` - Steam Deck OLED
  - NixOS with the SteamOS interface

- `dead-voxel` - Gaming PC
  - Hyprland
  - Geforce RTX 3060 12GB with AMD Ryzen 3600

- `blind-spots` - Home Server (just an old laptop)
  - Nextcloud
  - Forgejo

- `aria-math` - Another Home Server (also, an old laptop, though a little beefier)
  - meant to run game servers so that a minecraft server does not slow my nextcloud down

*What are those host names?*

They're all track names from [Minecraft - Volume Beta](https://minecraft.wiki/w/Minecraft_-_Volume_Beta).

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
    - check with `lsblk` on the remote machine whats the default device name
  - don't forget to add host configuration to `network.nix` 

2. `manage-hosts install <hostname> root@<ip-address>`
  - this is what calls `nixos-anywhere`
  - add `--build-on remote` to build on remote machine
