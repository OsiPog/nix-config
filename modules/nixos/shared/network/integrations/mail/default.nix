{
  config,
  hostName,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkMerge mkIf mkOption mkEnableOption mkDefault foldl';
  inherit (lib.lists) findFirst;
  inherit (lib.attrsets) genAttrs;
  inherit (lib.strings) toUpper splitString;
  inherit (config.lib.network) getAddress allPorts;

  networkCfg = config.network;
  hostCfg = networkCfg.hosts.${hostName};
  hostSrvs = hostCfg.services;

  integratedServices = ["lldap" "authelia"];
  integratedServiceEnable = foldl' (acc: elem: acc || (hostCfg.services.${elem}.enable && hostCfg.services.${elem}.integrations.mail.enable)) false integratedServices;
in
  mkMerge [
    {
      network.sharedModules = [
        ({...}: {
          options.services = genAttrs integratedServices (_: {
            integrations.mail = mkOption {
              description = "mail server integration";
              type = lib.types.submodule (integrationModule: let
                defaultHost = (findFirst (p: p.portName == "submissions") (throw "Mail Integration: submissions port it not defined on any host.") allPorts).hostName;
                address = getAddress {
                  portName = "submissions";
                  protocol = "submissions";
                  hostName = integrationModule.config.host;
                };
                mailDomain = getAddress {
                  portName = "submissions";
                  hostName = integrationModule.config.host;
                  appendPort = false;
                };
              in {
                options = {
                  enable = mkEnableOption "mail server integration";
                  host = mkOption {
                    description = "The host the mail server is running on.";
                    type = lib.types.str;
                  };
                  address = mkOption {
                    description = "Read only option of the submission address";
                    readOnly = true;
                    default = address;
                  };
                  notifierMail = mkOption {
                    description = "Mail address of the notifier mail account";
                    readOnly = true;
                    default = "noreply@${mailDomain}";
                  };
                  displayName = mkOption {
                    description = "Display name of the mail sender";
                    default = mailDomain;
                    readOnly = true;
                  };
                };
                config = mkIf integrationModule.config.enable {
                  host = mkDefault defaultHost;
                };
              });
              default = {};
            };
          });
        })
      ];
    }

    # --- SHARED
    # Define the mail notifier secret so all services that need it have access
    (mkIf (networkCfg.enable && integratedServiceEnable) {
      sops.secrets."ldap/notifier-pass" = {
        sopsFile = ./secrets.yaml;
        group = "mail-notifier";
        mode = "0440";
      };

      users.groups.${config.sops.secrets."ldap/notifier-pass".group} = {};
    })

    # SMTP SERVER
    #
    # --- MAILSERVER
    # no configuration necessary account is being created in lldap

    # SMTP CLIENTS
    #
    # --- LLDAP
    # Create the mail account
    (mkIf (networkCfg.enable && hostSrvs.lldap.enable && hostSrvs.lldap.integrations.mail.enable) (let
      inherit (hostSrvs.lldap.integrations) mail;
    in {
      users.users.lldap.extraGroups = [config.sops.secrets."ldap/notifier-pass".group];
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
    (mkIf (networkCfg.enable && hostSrvs.authelia.enable && hostSrvs.authelia.integrations.mail.enable) (let
      inherit (hostSrvs.authelia.integrations) mail;
    in {
      users.users.${config.services.authelia.instances.default.user}.extraGroups = [config.sops.secrets."ldap/notifier-pass".group];

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
  ]
