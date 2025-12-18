{
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption;

  cfg = config.services.porkbunAcme;
in {
  options.services.porkbunAcme = {
    enable = mkEnableOption "Porkbun ACME DNS challenge configuration";
    domain = mkOption {
      type = lib.types.str;
      default = config.networking.domain;
      description = "The domain of the cert. `config.networking.domain` by default.";
    };
  };

  config = mkIf cfg.enable {
    sops.secrets."acme/porkbun" = {sopsFile = ./secrets.yaml;};

    security.acme = {
      acceptTerms = true;
      defaults.email = "osibluber@pm.me";
      certs.${cfg.domain} = {
        domain = cfg.domain;
        dnsProvider = "porkbun";
        environmentFile = config.getSopsFile "acme/porkbun";
      };
    };
  };
}
