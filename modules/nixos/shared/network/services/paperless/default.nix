{
  config,
  lib,
  flake,
  ...
}: let
  inherit (lib) mkIf mkDefault mkMerge;
  inherit (lib.attrsets) getAttrs;
  inherit (flake.lib) mkNetworkHostServiceModule mkGroupsFromSecretsWithMembers mkSharedSecrets headAttrs;
  inherit (config.lib.network) getServiceVariables;

  inherit
    (getServiceVariables "paperless")
    serviceName
    networkCfg
    cfg
    stateDir
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({cfg, ...}: {
      provideEnable.ports.http = {
        protocol = "http";
        port = mkDefault 28981;
      };

      provideEnable.backup-paths.${serviceName} = {path = stateDir;};

      provideEnable.oidc-clients.${serviceName} = rec {
          secrets = mkSharedSecrets [clientSecretName] ./secrets.yaml;
          clientId = "paperless";
          clientName = "Paperless";
          hashedClientSecret = "$pbkdf2-sha512$310000$NjAbX7HaNka5ZHVVxuxWoA$HMG3WyHtHecgY6iSzJnvI4pZ.TJjyuJukjUXt4p2XxavOxLNJz4RnFiF3bcoSF4rjXPoIpmOK2d1oshOWrFTYw";
          clientSecretName = "paperless/oidc-secret";
          # allauth openid_connect callback: /accounts/oidc/<provider_id>/login/callback/
          redirectUris = let
            address = cfg.provide.ports.http.getAddress;
          in ["${address "https://<domain>"}/accounts/oidc/authelia/login/callback/"];
          scopes = ["openid" "profile" "email"];
          public = false;
          pkce.enabled = false;
          endpointAuthMethod = "client_secret_post";
      };
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    {
      services.paperless = {
        enable = true;
        port = cfg.provide.ports.http.port;
        address = "0.0.0.0";
        # PAPERLESS_URL drives ALLOWED_HOSTS / CSRF_TRUSTED_ORIGINS behind the proxy
        settings = {
          PAPERLESS_URL = cfg.provide.ports.http.getAddress "https://<domain>";
        };
      };
    }

    # OIDC SERVER INTEGRATION
    (let
      oidcServer = headAttrs cfg.require.oidc-servers;
      oidcClient = cfg.provide.oidc-clients.${serviceName};
      secrets = getAttrs [oidcClient.clientSecretName] oidcClient.secrets;
    in
      mkIf (cfg.require.oidc-servers != {}) {
        sops = {
          inherit secrets;
          templates.paperless-env = {
            # single-quoted: file is both `source`d and used as systemd EnvironmentFile.
            # toJSON emits double quotes only, so single-quote wrapping is safe.
            # attrset inlined so the file's shape is visible at a glance; server_url is
            # the Authelia base (allauth appends /.well-known/openid-configuration);
            # `secret` is the sops placeholder, substituted at activation.
            content = ''
              PAPERLESS_SOCIALACCOUNT_PROVIDERS='${builtins.toJSON {
                openid_connect = {
                  SCOPE = ["openid" "profile" "email"];
                  APPS = [
                    {
                      provider_id = "authelia";
                      name = oidcServer.name;
                      client_id = oidcClient.clientId;
                      secret = config.sops.placeholder.${oidcClient.clientSecretName};
                      settings.server_url = oidcServer.getAddress "https://<domain>";
                    }
                  ];
                };
              }}'
            '';
            owner = "paperless";
          };
        };
        users.groups = mkGroupsFromSecretsWithMembers secrets ["paperless"];

        services.paperless = {
          environmentFile = config.sops.templates.paperless-env.path;
          settings = {
            # activate the allauth OIDC provider
            PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
            PAPERLESS_SOCIAL_AUTO_SIGNUP = "true";
            PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS = "true";
            # SSO-only
            PAPERLESS_DISABLE_REGULAR_LOGIN = "true";
            PAPERLESS_REDIRECT_LOGIN_TO_SSO = "true";
          };
        };
      })
  ]);
}
