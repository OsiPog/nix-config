{
  config,
  lib,
  flake,
  ...
}: let
  inherit (lib) mkMerge mkIf mkOption;
  inherit (config.lib.network) getIntegrationVariables getAddress;
  inherit (flake.lib) mkNetworkHostServiceIntegrationModule;

  inherit
    (getIntegrationVariables "mail" ["lldap" "authelia"])
    integrationName
    integratedServices
    networkCfg
    hostSrvs
    serviceWithIntegrationEnable
    integratedServiceEnable
    ;
in {
  imports = [
    (mkNetworkHostServiceIntegrationModule {
        inherit integratedServices integrationName;
        serviceName = "mailserver";
        portName = "submissions";
        protocol = "submissions";
      } ({cfg, ...}: {
        optionsIntegration = {
          notifierMail = mkOption {
            description = "Mail address of the notifier mail account";
            readOnly = true;
            default = let
              mailDomain = getAddress {
                portName = "submissions";
                hostName = cfg.host;
                appendPort = false;
              };
            in "noreply@${mailDomain}";
          };
          displayName = mkOption {
            description = "Display name of the mail sender";
            readOnly = true;
            default = let
              mailDomain = getAddress {
                portName = "submissions";
                hostName = cfg.host;
                appendPort = false;
              };
            in
              mailDomain;
          };
        };
      }))
  ];

  config = mkIf networkCfg.enable (mkMerge [
    # --- SHARED
    # Define the mail notifier secret so all services that need it have access
    (mkIf integratedServiceEnable {
      sops.secrets."ldap/notifier-pass" = {
        sopsFile = ./secrets.yaml;
        group = "mail-notifier";
        mode = "0440";
      };

      users.groups.mail-notifier = {};
    })

    # SMTP SERVER
    #
    # --- MAILSERVER
    # no configuration necessary account is being created in lldap

    # SMTP CLIENTS
    #
    # --- LLDAP
    # Create the mail account
    (mkIf (serviceWithIntegrationEnable "lldap") (let
      inherit (hostSrvs.lldap.integrations) mail;
    in {
      users.users.lldap.extraGroups = ["mail-notifier"];
      services.lldap.bootstrap = {
        enable = true;
        users.configs.notifier = {
          email = mail.notifierMail;
          inherit (mail) displayName;
          password_file = config.getSopsFile "ldap/notifier-pass";
          groups = [
            "email" # needs to be in email group to send mail
          ];
        };
      };
    }))

    # --- AUTHELIA
    # Configure Authelia to use the mail notifier account
    (mkIf (serviceWithIntegrationEnable "authelia") (let
      inherit (hostSrvs.authelia.integrations) mail;
    in {
      users.users.${config.services.authelia.instances.default.user}.extraGroups = ["mail-notifier"];

      services.authelia.instances.default = {
        environmentVariables = {
          AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = config.getSopsFile "ldap/notifier-pass";
        };
        settings = {
          notifier.smtp = {
            address = mail.address;
            sender = "${mail.displayName} <${mail.notifierMail}>";
            username = mail.notifierMail;
          };
        };
      };
    }))
  ]);
}
