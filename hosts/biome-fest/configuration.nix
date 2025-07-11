{self, ...}: {
  imports = with self.nixosModules; [
    ./hardware-configuration.nix

    ({pkgs, ...}: {boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;})

    allow-some-unfree
    fingerprint
    laptop
    monitors
    networking
    obs-studio
    printing
    sound
    speicherfresser
    steam

    "${self}/users/osi"
  ];

  # Don't change, will break things.
  system.stateVersion = "23.11"; # Did you read the comment?
}
