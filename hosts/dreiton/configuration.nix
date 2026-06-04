{flake, ...}: {
  imports = with flake.nixosModules; [
    ./hardware-configuration.nix
    shared

    disko-basic

    makemkv
  ];

  disko.devices.disk.disk1.device = "/dev/disk/by-id/ata-Apacer_AS340_240GB_J45235R004619";

  # Disable suspend on lid close (this is an old laptop)
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  nixpkgs.config.allowUnfree = true;

  # Don't change, will break things!
  system.stateVersion = "26.05";
}
