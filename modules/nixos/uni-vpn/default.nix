{inputs, ...}: {
  imports = [inputs.nix-config-private.nixosModules.uni-vpn];

  sops.secrets."other/uni-vpn-auth" = {sopsFile = ./secrets.yaml;};
}
