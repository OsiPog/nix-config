{
  config,
  lib,
  flake,
  hostName,
  ...
}: let
  inherit (builtins) head elem getAttr;
  inherit (lib) mkIf mkMerge mkDefault;
  inherit (lib.attrsets) getAttrs genAttrs;

  inherit (flake.lib) mkNetworkHostServiceModule mkGroupsFromSecretsWithMembers mkSharedSecrets mkMergeTopLevel;
  inherit (config.lib.network) getServiceVariables;

  inherit
    (getServiceVariables "authelia")
    serviceName
    networkCfg
    cfg
    ;

  stateDir = "/var/lib/authelia-default";
  getAddress = cfg.provide.ports.http.getAddress;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({
      cfg,
      ...
    }: let
      getAddress = cfg.provide.ports.http.getAddress;
    in {
      provideEnable = {
        ports.http = {
          protocol = "http";
          port = 9091;
          proxy.extraConfig.locations."/api/oidc" = {
            proxyPass = getAddress "http://<host>:<port>";
            extraConfig = ''
              add_header Access-Control-Allow-Origin "*";
              add_header Access-Control-Allow-Methods "*";
            '';
          };
        };

        ldap-clients = [
          {
            groups = genAttrs (map (getAttr "allowedGroup") cfg.require.oidc-clients) (_: {});
          }
        ];

        mail-clients = [
          rec {
            secrets = mkSharedSecrets [mailAccount.secretName] ./secrets.yaml;
            mailAccount = {
              uid = "authelia-mail-notifier";
              email = "noreply.authelia@${cfg.require.mail-server.getAddress "<domain>"}";
              display = "Authelia";
              secretName = "authelia/mail-pass";
            };
          }
        ];

        oidc-server = {
          inherit getAddress;
          adminGroup = cfg.require.ldap-server.adminGroup or "admin";
          name = "Authelia";
        };
      };
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.provide.ports.http.proxy.domain != null;
          message = "Authelia needs to be reverse proxied as https is required.";
        }
      ];

      # Authelia secrets
      sops.secrets = {
        "authelia/jwtSecret" = {
          owner = config.services.authelia.instances.default.user;
          sopsFile = ./secrets.yaml;
        };
        "authelia/storageEncryptionKey" = {
          owner = config.services.authelia.instances.default.user;
          sopsFile = ./secrets.yaml;
        };
        "authelia/oidcIssuerPrivateKeyFile" = {
          owner = config.services.authelia.instances.default.user;
          sopsFile = ./secrets.yaml;
        };
      };

      # Authelia service configuration
      services.authelia.instances.default = {
        enable = true;
        secrets = {
          jwtSecretFile = config.getSopsFile "authelia/jwtSecret";
          storageEncryptionKeyFile = config.getSopsFile "authelia/storageEncryptionKey";
          oidcIssuerPrivateKeyFile = config.getSopsFile "authelia/oidcIssuerPrivateKeyFile";
        };
        settings = {
          server.address = "tcp://:${toString cfg.provide.ports.http.port}";
          log.level = "info";
          storage.local.path = "${stateDir}/db.sqlite3";
          session.cookies = [
            {
              domain = getAddress "<domain>";
              authelia_url = getAddress "https://<domain>";
            }
          ];
          access_control.default_policy = mkDefault "two_factor";
        };
      };
    }

    # LDAP SERVER INTEGRATION
    (let
      ldapServer = cfg.require.ldap-server;
      secrets = getAttrs [ldapServer.users.manage.secretName] ldapServer.secrets;
    in
      mkIf (ldapServer != null) {
        sops = {inherit secrets;};
        users.groups = mkGroupsFromSecretsWithMembers secrets [config.services.authelia.instances.default.user];
        services.authelia.instances.default = {
          environmentVariables.AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE = config.getSopsFile ldapServer.users.manage.secretName;
          settings.authentication_backend = {
            refresh_interval = mkDefault "1m";
            ldap = {
              implementation = "lldap";
              address = ldapServer.getAddress "<protocol>://<domain>:<port>";
              base_dn = ldapServer.baseDN;
              user = "uid=${ldapServer.users.manage.dn},ou=people,${ldapServer.baseDN}";
            };
          };
        };
      })

    # OIDC CLIENTS INTEGRATION
    (mkMergeTopLevel ["services"] (map (client: {
        services.authelia.instances.default.settings.identity_providers.oidc = {
          cors.allowed_origins_from_client_redirect_uris = true;
          claims_policies.${client.clientId}.id_token = client.idTokenClaims;
          authorization_policies.${client.clientId} = {
            default_policy = "deny";
            rules = [
              {
                policy = config.services.authelia.instances.default.settings.access_control.default_policy;
                subject = ["group:${client.allowedGroup}" "user:admin"];
              }
            ];
          };
          clients = [
            {
              client_id = client.clientId;
              client_name = client.clientName;
              client_secret =
                if client.public
                then ""
                else client.hashedClientSecret;
              claims_policy = client.clientId;
              authorization_policy = client.clientId;
              public = client.public;
              require_pkce = client.pkce.enabled;
              pkce_challenge_method =
                if client.pkce.enabled
                then client.pkce.method
                else "";
              redirect_uris = client.redirectUris;
              scopes = client.scopes;
              response_types = ["code"];
              grant_types = ["authorization_code"];
              access_token_signed_response_alg = "none";
              userinfo_signed_response_alg = "none";
              consent_mode = "pre-configured";
              token_endpoint_auth_method =
                if client.public
                then "none"
                else client.endpointAuthMethod;
            }
          ];
        };
      })
      cfg.require.oidc-clients))

    # MAIL SERVER INTEGRATION
    (let
      mailServer = cfg.require.mail-server;
      mailClient = head cfg.provide.mail-clients;
      secrets = getAttrs [mailClient.mailAccount.secretName] mailClient.secrets;
    in
      mkIf (mailServer != null) {
        sops = {inherit secrets;};
        users.groups = mkGroupsFromSecretsWithMembers secrets [config.services.authelia.instances.default.user];
        services.authelia.instances.default = {
          environmentVariables = {
            AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = config.getSopsFile mailClient.mailAccount.secretName;
          };
          settings = {
            notifier.smtp = {
              address = mailServer.getAddress "<protocol>://<domain>:<port>";
              sender = "${mailClient.mailAccount.display} <${mailClient.mailAccount.email}>";
              username = mailClient.mailAccount.email;
            };
          };
        };
      })
  ]);
}
