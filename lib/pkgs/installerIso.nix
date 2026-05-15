{
  pkgs,
  flake,
  ...
}: let
  inherit (pkgs) lib system;
  inherit (lib) mkForce pipe;
  inherit (flake.inputs.nixpkgs.lib) nixosSystem;
in
  (nixosSystem {
    inherit system;
    specialArgs = {
      inherit flake;
      inherit (flake) inputs;
      hostName = "nixos-installer";
    };
    modules = with flake.nixosModules; [
      shared
      "${flake.inputs.nixpkgs.outPath}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
      "${flake.inputs.nixpkgs.outPath}/nixos/modules/installer/cd-dvd/channel.nix"
      ({config, ...}: {
        # turn off secrets
        sops.secrets = mkForce {};

        # installer is not part of the network
        network.enable = false;
        network.hosts.nixos-installer = {};

        # allow any host to connect to this installer with passwordless login
        users.users.root.openssh.authorizedKeys.keys = pipe flake.lib.nixosHostNames [
          (map (host: config.network.hosts.${host}.ssh.publicKey))
        ];
      })
    ];
  })
.config.system.build.isoImage
