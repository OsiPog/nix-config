{
  lib,
  config,
  inputs,
  ...
}: let
  cfg = config.first-install;
in {
  options.first-install = {
    enable = lib.mkEnableOption "special configuration for the first install with nixos-anywhere";
  };
  config = lib.mkIf cfg.enable {
    # disabledModules = [inputs.determinate-nix];

    sops.secrets = lib.mkForce {};
  };
}
