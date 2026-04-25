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
    stateDir
    ports
    integrationHelpers
    ;
  ldapServer = cfg.integrations.ldap.remote.server;
in {
  imports = [
    inputs.simple-nixos-mailserver.nixosModules.default
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      configEnable = {
        ports.submissions.port = 465;
      };
      configService.integrations.ldap.local.client = {
        createGroups.email = {};
        createUserAttributes = {
          mail-aliases = {
            dataType = "string";
            editable = false;
            multiple = true;
            visible = true;
          };
        };
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
        stateVersion = 3;
        mailDirectory = stateDir;
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
      };
    }

    # LDAP INTEGRATION
    (mkIf cfg.integrations.ldap.enable (let
      usersFilter = username: "(&(|(mail=${username})(mail-aliases=${username}))(memberof=cn=email,ou=groups,${ldapServer.baseDN}))";
    in
      mkMerge [
        (integrationHelpers.ldap.mkRegisterIntegrationSecretsConfig {
          secrets.searchUserPass = ldapServer.searchUser.secret;
          users = [
            # "dovecot" # runs as root
            "postfix"
          ];
        })

        {
          mailserver.ldap = {
            enable = true;
            searchBase = ldapServer.baseDN;
            uris = [(ldapServer.address "protocol://domain:port")];
            bind = {
              dn = ldapServer.searchUser.dn;
              passwordFile = integrationHelpers.ldap.getSopsFile "searchUserPass";
            };
            postfix = {
              filter = usersFilter "%S";
              uidAttribute = "uid";
              mailAttribute = "mail";
            };
            dovecot.passFilter = usersFilter "%{user}";
          };
        }
      ]))
  ]);
}
