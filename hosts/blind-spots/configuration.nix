{flake, ...}: {
  imports = with flake.nixosModules; [
    ./hardware-configuration.nix
    shared

    disko-basic
  ];

  services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";

  # systemd.services.turn-off-display

  # Don't change, will break things!
  system.stateVersion = "25.11";
}
