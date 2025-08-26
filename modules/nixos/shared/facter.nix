{ inputs, hostName, ... }:
{
  imports = with inputs; [
    nixos-facter-modules.nixosModules.facter
  ];
  facter.reportPath = ../../.. + "/hosts/${hostName}/facter.json";
}
