{
  lib,
  flake,
  ...
}: {
  imports = with flake.nixosModules; [
    shared

    "${flake.inputs.nixpkgs.outPath}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    "${flake.inputs.nixpkgs.outPath}/nixos/modules/installer/cd-dvd/channel.nix"
  ];

  first-install.enable = true;

  # SSH access
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };
  users.users.root = {
    password = "nixos";
    hashedPasswordFile = lib.mkForce null;
    hashedPassword = lib.mkForce null;
  };
}
