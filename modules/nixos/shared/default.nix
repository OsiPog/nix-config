{lib, ...}: {
  imports = [
    ./boot.nix
    ./locale.nix
    ./networking.nix
    ./nix-settings.nix
    ./nixpkgs.nix
    ./packages.nix
    ./secrets.nix
    ./users.nix
    ./openssh.nix
    ./first-install.nix

    ./network
    ../../../network.nix
  ];
}
