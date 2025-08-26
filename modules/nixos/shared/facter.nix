{inputs, flake, hostName, ...}: {
  imports = with inputs; [
    nixos-facter-modules.nixosModules.facter
  ];
  facter.reportPath = "${flake}/hosts/${hostName}/facter.json";
}
