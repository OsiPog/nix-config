{self, ...}: {
  imports = with self.nixosModules; [
    disko-basic
  ];

  system.stateVersion = "25.11";
}
