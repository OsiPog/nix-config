{...}: {
  imports = [
    ./boot.nix
    ./facter.nix
    ./locale.nix
    ./networking.nix
    ./nix-settings.nix
    ./nixpkgs.nix
    ./packages.nix
    ./secrets.nix
    ./users.nix
    ./openssh.nix

    ./network
    ../../../network.nix
  ];
}
