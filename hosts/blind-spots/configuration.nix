{flake, ...}: {
  imports = with flake.nixosModules; [
    ./hardware-configuration.nix
    shared

    disko-basic
  ];

  # Do not suspend when the lid is closed (this is a laptop)
  services.logind.settings.Login.HandleLidSwitch = "ignore";

  # systemd.services.turn-off-display

  # Don't change, will break things!
  system.stateVersion = "25.11";
}
