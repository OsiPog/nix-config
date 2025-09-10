{
  flake,
  config,
  ...
}: {
  imports = with flake.nixosModules; [
    shared

    disko-basic
  ];

  system.stateVersion = "25.11";
}
