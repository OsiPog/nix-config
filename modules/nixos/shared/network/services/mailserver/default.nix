# Some extra steps are needed after install more here: https://nixos-mailserver.readthedocs.io/en/latest/setup-guide.html
{
  inputs,
  config,
  lib,
  flake,
  hostName,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  inherit (flake.lib) mkServiceOptionsModule;

  serviceName = "mailserver";
  networkCfg = config.network;
  cfg = networkCfg.hosts.${hostName}.services.${serviceName};
in {
  imports = [
    inputs.simple-nixos-mailserver.nixosModules.default
    (mkServiceOptionsModule serviceName)
  ];

  config = mkMerge [
    {
    }
    (mkIf (networkCfg.enable && cfg.enable) {
      # assertions = [
      #   {
      #     assertion = !cfg.reverseProxy.enable;
      #     message = "Due to mail protocol requirements, mailserver cannot be reverse proxied.";
      #   }
      # ];

      sops.secrets."mailserver/pass-hashes/admin" = {sopsFile = ./secrets.yaml;};

      mailserver = {
        enable = true;
        stateVersion = 3;
        fqdn = "mail.${config.networking.domain}";
        domains = [config.networking.domain];

        # A list of all login accounts. To create the password hashes, use
        # nix-shell -p mkpasswd --run 'mkpasswd -sm bcrypt'
        loginAccounts = {
          "admin@${config.networking.domain}" = {
            hashedPasswordFile = config.getSopsFile "mailserver/pass-hashes/admin";
          };
        };

        certificateScheme = "acme";
        acmeCertificateName = "default";
      };
    })
  ];
}
