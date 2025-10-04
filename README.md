# nixos-config

This is the NixOS flake which defines the system on all of my devices running NixOS. If you want to use this config yourself then I must disappoint you. It will fail because you'll need my SSH keys for it

## Documentation

### Directory Structure

[**hosts**](./hosts/README.md)

[**modules**](./modules/README.md)

[**users**](./users/README.md)

### Hosts

- `biome-fest` - My main laptop
  - Hyprland
  - acts as my workstation until I actually have one

- `haunt-muskie` - Small Hetzner VPS
  - thats where https://kazuka.zip points to
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

*What are those host names?*

They're all track names from [Minecraft - Volume Beta](https://minecraft.wiki/w/Minecraft_-_Volume_Beta).

## Guides to remember

### Creating a new host

Here I use [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) to deploy new hosts anywhere.

1. `manage-hosts create <hostname>`
  - might need to change `disko.devices.disk.disk1.device` to something else than `"/dev/sda"` if needed
    - check with `lsblk` on the remote machine whats the default device name
  - don't forget to add host configuration to `network.nix`

2. `manage-hosts install <hostname> root@<ip-address>`
  - this is what calls `nixos-anywhere`
  - add `--build-on remote` to build on remote machine

### Rotating ssh keys

1. Temporarily decrypt the secrets file: `sudo sops --decrypt --in-place secrets/biome-fest.yaml`

2. Backup current SSH key: `sudo cp /etc/ssh/id_ed25519 /etc/ssh/id_ed25519_old`

3. Generate new key: `sudo ssh-keygen -t ed25519 -f /etc/ssh/id_ed25519 -N ""`

4. Put new public key into `hosts.nix`. (`wl-copy < /etc/ssh/id_ed25519.pub`) to correct host

5. Generate new AGE key from new SSH key: `sudo ssh-to-age -private-key -i /etc/ssh/id_ed25519 -o /root/.config/sops/age/keys.txt`

6. Get public AGE key: `sudo age-keygen -y /root/.config/sops/age/keys.txt | wl-copy`

7. Put the new age key into .sops.yaml to the correct host

6. encrypt the secrets file again: `sudo sops --encrypt --in-place secrets/biome-fest.yaml`
