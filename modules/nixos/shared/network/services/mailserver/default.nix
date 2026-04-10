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
  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getServiceVariables;

  inherit
    (getServiceVariables "mailserver")
    serviceName
    networkCfg
    cfg
    ports
    integrations
    ;
in {
  imports = [
    inputs.simple-nixos-mailserver.nixosModules.default
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      configEnable = {
        ports.submissions.port = 465;
      };
      integrationsEnable = {
        ldap.clients = [
          {
            group = "email";
            extraUserAttributes = {
              mail-aliases = {
                attributeType = "STRING";
                isEditable = false;
                isList = true;
                isVisible = true;
              };
            };
          }
        ];
      };
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    {
      assertions = [
        {
          assertion = !ports.submissions.reverseProxy.enable;
          message = "Due to mail protocol requirements, mailserver cannot be reverse proxied.";
        }
      ];

    mailserver = {
      enable = true;
      stateVersion = 4;
      mailDirectory = cfg.stateDir;
      fqdn = "mail.${config.networking.domain}";
      domains = [config.networking.domain] ++ config.network.hosts.${hostName}.extraDomains;
      enableSubmissionSsl = true;

        # # A list of all login accounts. To create the password hashes, use
        # # nix-shell -p mkpasswd --run 'mkpasswd -sm bcrypt'
        # loginAccounts = {
        #   "admin@${config.networking.domain}" = {
        #     hashedPasswordFile = config.getSopsFile "mailserver/pass-hashes/admin";
        #   };
        # };

        certificateScheme = "acme";
        acmeCertificateName = config.networking.domain;

        ldap = mkIf (cfg.integrations.ldap.enable) {
          enable = true;
        };
      };
    }

    (mkIf cfg.integrations.ldap.enable (let
      inherit (integrations.ldap) server;
      usersFilter = username: "(&(|(mail=${username})(mail-aliases=${username}))(memberof=cn=email,ou=groups,${server.baseDN}))";
    in {
      mailserver.ldap = {
        enable = true;
        searchBase = server.baseDN;
        uris = [(server.address "protocol://domain:port")];
        bind = {
          dn = server.searchUserDN;
          passwordFile = config.getSopsFile "ldap/search-user-pass";
        };
        postfix = {
          filter = usersFilter "%S";
          uidAttribute = "uid";
          mailAttribute = "mail";
        };
        dovecot.passFilter = usersFilter "%{user}";
      };
    }))
  ]);
}
