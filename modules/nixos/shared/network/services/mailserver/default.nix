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
  inherit (lib.attrsets) filterAttrs;
  inherit (flake.lib) mkNetworkHostServiceModule mkGroupsFromSecretsWithMembers;
  inherit (config.lib.network) getServiceVariables;

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
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      configEnable = {
        ports.submissions.port = 465;
      };
      provideEnable.ldap-clients = [
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
      ];
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
    (let
      ldapServer = cfg.require.ldap-server;
      secrets = filterAttrs (name: _: name == ldapServer.users.search.secretName) ldapServer.secrets;
    in
      mkIf (ldapServer != null) (let
        usersFilter = username: "(&(|(${ldapServer.attributes.email}=${username})(mail-aliases=${username}))(${ldapServer.attributes.memberof}=cn=email,ou=groups,${ldapServer.baseDN}))";
      in {
        sops = {inherit secrets;};

        users.groups = mkGroupsFromSecretsWithMembers secrets ["postfix"];
        mailserver.ldap = {
          enable = true;
          searchBase = ldapServer.baseDN;
          uris = [(ldapServer.address "protocol://domain:port")];
          bind = {
            dn = ldapServer.users.search.dn;
            passwordFile = cfg.getSopsFile ldapServer.users.search.secretName;
          };
          postfix = {
            filter = usersFilter "%S";
            uidAttribute = ldapServer.attributes.uid;
            mailAttribute = ldapServer.attributes.email;
          };
          dovecot.passFilter = usersFilter "%{user}";
        };
      }))
  ]);
}
