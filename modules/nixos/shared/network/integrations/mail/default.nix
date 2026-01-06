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
  inherit (config.lib.network) getAddress allPorts;

  networkCfg = config.network;
  hostCfg = networkCfg.hosts.${hostName};
  hostSrvs = hostCfg.services;

  integratedServices = ["portunus" "authelia"];
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
      sops.secrets."portunus/notifier-pass" = {
        sopsFile = ./secrets.yaml;
        group = "mail-notifier";
        mode = "0440";
      };

      users.groups.${config.sops.secrets."portunus/notifier-pass".group} = {};
    })

    # SMTP SERVER
    #
    # --- MAILSERVER
    # no configuration necessary account is being created in portunus

    # SMTP CLIENTS
    #
    # --- PORTUNUS
    # Create the mail account
    (mkIf (networkCfg.enable && hostSrvs.portunus.enable && hostSrvs.portunus.integrations.mail.enable) (let
      inherit (hostSrvs.portunus.integrations) mail;
    in {
      # TODO: for some reason the portunus user cannot read the secret even though the group an permissions are correct
      sops.secrets."portunus/notifier-pass".owner = config.services.portunus.user;

      users.users.${config.services.portunus.user}.extraGroups = [config.sops.secrets."portunus/notifier-pass".group];
      services.portunus.seedSettings = {
        groups = [
          # only people in the email group may login with email servers
          {
            name = "email";
            long_name = "Email";
            members = ["notifier"];
          }
        ];
        users = [
          {
            login_name = "notifier";
            given_name = "Mail";
            family_name = "Notifier";
            email = mail.notifierMail;
            password.from_command = ["cat" (config.getSopsFile "portunus/notifier-pass")];
          }
        ];
      };
    }))

    # --- AUTHELIA
    # Configure Authelia to use the mail notifier account
    (mkIf (networkCfg.enable && hostSrvs.authelia.enable && hostSrvs.authelia.integrations.mail.enable) (let
      inherit (hostSrvs.authelia.integrations) mail;
    in {
      users.users.${config.services.authelia.instances.default.user}.extraGroups = [config.sops.secrets."portunus/notifier-pass".group];

      services.authelia.instances.default = {
        environmentVariables = {
          AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = config.getSopsFile "portunus/notifier-pass";
        };
        settings = {
          notifier.smtp = {
            address = mail.address;
            sender = mail.notifierMail;
            username = mail.notifierMail;
          };
        };
      };
    }))
  ]
