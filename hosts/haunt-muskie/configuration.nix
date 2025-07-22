{self, ...}: {
  imports = with self.nixosModules; [
    disko-basic

    ../../users/leaf
  ];

  system.stateVersion = "25.11";
}