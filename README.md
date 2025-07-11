# nixos-config

This is the NixOS flake which defines the system on all of my devices running NixOS. If you want to use this config yourself then I must disappoint you. It will fail because you'll need my SSH keys for it

## Documentation

### Directory Structure

[**hosts**](./hosts/README.md)

[**modules**](./modules/README.md)

[**users**](./users/README.md)

## Rotating ssh keys

1. Temporarily decrypt the secrets file: `sudo sops --decrypt --in-place secrets/biome-fest.yaml`

2. Backup current SSH key: `sudo cp /etc/ssh/id_ed25519 /etc/ssh/id_ed25519_old`

3. Generate new key: `sudo ssh-keygen -t ed25519 -f /etc/ssh/id_ed25519 -N ""`

4. Put new public key into `hosts.nix`. (`wl-copy < /etc/ssh/id_ed25519.pub`) to correct host

5. Generate new AGE key from new SSH key: `sudo ssh-to-age -private-key -i /etc/ssh/id_ed25519 -o /root/.config/sops/age/keys.txt`

6. Get public AGE key: `sudo age-keygen -y /root/.config/sops/age/keys.txt | wl-copy`

7. Put the new age key into .sops.yaml to the correct host

6. encrypt the secrets file again: `sudo sops --encrypt --in-place secrets/biome-fest.yaml`
