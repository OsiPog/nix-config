{
  lib,
  config,
  ...
}: let
  cfg = config.first-install;
in {
  options.first-install = {
    enable = lib.mkEnableOption "special configuration for the first install with nixos-anywhere";
  };

  config = lib.mkIf cfg.enable {
    # Disable secrets as the sops-install-secrets activation command does not work in nix installer during `nixos-install`
    sops.secrets = lib.mkForce {};

    # Disable determinate nix as we do not want to build it from scratch
    # determinate.enable = false;
  };
}
