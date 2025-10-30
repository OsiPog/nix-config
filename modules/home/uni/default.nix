{inputs, ...}: {
  imports = [
    inputs.nix-config-private.homeModules.uni
  ];

  sops.secrets = {
    "ssh-keys/uni-gitlab/private" = {sopsFile = ./secrets.yaml;};
    "ssh-keys/ag-vps/private" = {sopsFile = ./secrets.yaml;};
    "ssh-keys/ag-git/private" = {sopsFile = ./secrets.yaml;};
  };
}
