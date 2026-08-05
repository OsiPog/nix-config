# Some extra steps are needed after install more here: https://nixos-mailserver.readthedocs.io/en/latest/setup-guide.html
{
  inputs,
  config,
  lib,
  flake,
  hostName,
  ...
}: let
  inherit (lib) mkIf mkMerge mkForce;
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
          reverseProxy.method = "stream";
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
              groups.${serviceName} = {};
              extraUserAttributes = {
                mail-aliases = {
                  dataType = "string";
                  editable = false;
                  multiple = false;
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
                groups = [serviceName];
              };
            })
            cfg.require.mail-clients);
      };
    }))

    flake.nixosModules.porkbunAcme
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    {
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

        x509.useACMEHost = config.networking.domain;
      };
    }

    # LDAP INTEGRATION
    (let
      ldapServer = cfg.require.ldap-server;
      secrets = getAttrs [ldapServer.users.search.secretName] ldapServer.secrets;
    in
      mkIf (ldapServer != null) (let
        usersFilter = username: "(&(|(${ldapServer.attributes.email}=${username})(mail-aliases=${username}))(${ldapServer.attributes.memberof}=cn=${serviceName},ou=groups,${ldapServer.baseDN}))";
      in {
        sops = {inherit secrets;};

        users.groups = mkGroupsFromSecretsWithMembers secrets ["postfix"];
        mailserver.ldap = {
          enable = true;
          scope = "one";
          base = ldapServer.baseDN;
          uris = [(ldapServer.address "proxyProtocol://domain:port")];
          bind = {
            dn = "cn=${ldapServer.users.search.dn},ou=people,${ldapServer.baseDN}";
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
          dovecot.userFilter = usersFilter "%{user}";
        };

        # TODO: remove when fixed upstream
        services.dovecot2.settings."passdb ldap" = mkForce {
          bind = "yes";
          filter = config.mailserver.ldap.dovecot.passFilter;
        };
        # TODO: same here
        services.postfix.submissionsOptions.smtpd_sender_login_maps =
          mkForce "ldap:${config.sops.templates.postfixSenderLoginMapsMain.path}";
        sops.templates = let
          cfg = config.mailserver;
          ldapAuthBlock = ''
            server_host = ${ldapServer.address "proxyProtocol://domain:port"}
            start_tls = no
            version = 3
            tls_ca_cert_file = ${cfg.ldap.caFile}
            tls_require_cert = yes

            search_base = ${cfg.ldap.base}
            scope = ${cfg.ldap.scope}

            bind = yes
            bind_dn = ${cfg.ldap.bind.dn}
            bind_pw = ${config.sops.placeholder.${ldapServer.users.search.secretName}}

            query_filter = ${cfg.ldap.postfix.filter}
          '';
        in {
          postfixSenderLoginMapsMain = {
            owner = "postfix";
            content = ''
              ${ldapAuthBlock}
              result_attribute = ${cfg.ldap.attributes.mail}
            '';
          };
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
