{
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkDefault mkIf mkOption;

  cfg = config.services.porkbunAcme;
in {
  options.services.porkbunAcme = {
    enable = mkEnableOption "Porkbun ACME DNS challenge configuration";
    certName = mkOption {
      type = lib.types.str;
      default = "default";
      description = "The name of the cert in `security.acme.certs`.";
    };
    domain = mkOption {
      type = lib.types.str;
      default = config.networking.domain;
      description = "The domain of the cert. `config.networking.domain` by default.";
    };
  };

  config = mkIf cfg.enable {
    users.users.nginx.extraGroups = ["acme"];

    sops.secrets."acme/porkbun" = {sopsFile = ./secrets.yaml;};

    security.acme = {
      acceptTerms = true;
      defaults.email = "osibluber@pm.me";
      certs.${cfg.certName} = {
        domain = cfg.domain;
        dnsProvider = "porkbun";
        environmentFile = config.getSopsFile "acme/porkbun";
      };
    };
  };
}
