{self, ...}: {
  imports = with self.nixosModules; [
    disko-basic

    theme-prismarine

    ../../users/leaf
  ];

  system.stateVersion = "25.11";
}