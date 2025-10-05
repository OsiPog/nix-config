{config, ...}: {
  sops.secrets."api-keys/nix-access-tokens" = {sopsFile = ./secrets.yaml;};

  # Add github token to github calls
  nix.extraOptions = "!include " + config.getSopsFile "api-keys/nix-access-tokens";
}
