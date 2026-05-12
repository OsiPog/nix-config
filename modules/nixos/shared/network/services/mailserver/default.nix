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
  inherit (lib.attrsets) getAttrs;
  inherit (flake.lib) mkNetworkHostServiceModule mkGroupsFromSecretsWithMembers mkMergeTopLevel;
  inherit (config.lib.network) getServiceVariables getAddress;

  inherit
    (getServiceVariables "mailserver")
    serviceName
    networkCfg
    cfg
    ports
    ;
in {
  imports = [
    inputs.simple-nixos-mailserver.nixosModules.default
    (mkNetworkHostServiceModule {inherit serviceName;} ({
      cfg,
      name,
      ...
    }: {
      configEnable = {
        ports.submissions = {
          protocol = "submissions";
          port = 465;
        };
      };
      provideEnable = {
        mail-server.address = getAddress {
          portName = "submissions";
          hostName = name;
        };

        ldap-clients =
          [
            {
              groups.email = {};
              extraUserAttributes = {
                mail-aliases = {
                  dataType = "string";
                  editable = false;
                  multiple = true;
                  visible = true;
                };
              };
            }
          ]
          # translate mail accounts to ldap accounts (is connected to ldap)
          ++ (map (mailClient: {
              secrets = getAttrs [mailClient.mailAccount.secretName] mailClient.secrets;
              users.${mailClient.mailAccount.uid} = {
                inherit (mailClient.mailAccount) display email secretName;
              };
            })
            cfg.require.mail-clients);
      };
    }))

    flake.nixosModules.porkbunAcme
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    {
      assertions = [
        {
          assertion = !ports.submissions.reverseProxy.enable;
          message = "Due to mail protocol requirements, mailserver cannot be reverse proxied.";
        }
      ];

      services.porkbunAcme.enable = true;

      mailserver = {
        enable = true;
        stateVersion = 4;
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

        mailserver.x509.useACMEHost = config.networking.domain;
      };
    }

    # LDAP INTEGRATION
    (let
      ldapServer = cfg.require.ldap-server;
      secrets = getAttrs [ldapServer.users.search.secretName] ldapServer.secrets;
    in
      mkIf (ldapServer != null) (let
        usersFilter = username: "(&(|(${ldapServer.attributes.email}=${username})(mail-aliases=${username}))(${ldapServer.attributes.memberof}=cn=email,ou=groups,${ldapServer.baseDN}))";
      in {
        sops = {inherit secrets;};

        users.groups = mkGroupsFromSecretsWithMembers secrets ["postfix"];
        mailserver.ldap = {
          enable = true;
          base = ldapServer.baseDN;
          uris = [(ldapServer.address "proxyProtocol://domain:port")];
          bind = {
            dn = ldapServer.users.search.dn;
            passwordFile = config.getSopsFile ldapServer.users.search.secretName;
          };
          attributes = with ldapServer.attributes; {
            inherit password;
            uuid = uid;
            username = uid;
            mail = email;
          };
          postfix.filter = usersFilter "%S";
          dovecot.passFilter = usersFilter "%{user}";
        };
      }))

    # MAIL CLIENTS INTEGRATION (only register mail accounts when ldap is not set)
    (mkIf (cfg.require.ldap-server == null) (mkMergeTopLevel ["sops" "users" "mailserver"] (map (mailClient: {
        sops.secrets = mailClient.secrets;

        users.groups = mkGroupsFromSecretsWithMembers mailClient.secrets ["postfix"];

        mailserver.accounts."${mailClient.mailAccount.email}".passwordFile = config.getSopsFile mailClient.mailAccount.secretName;
      })
      cfg.require.mail-clients)))
  ]);
}
