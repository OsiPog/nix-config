{
  config,
  lib,
  flake,
  ...
}: let
  inherit (builtins) head replaceStrings;
  inherit (lib) mkIf mkDefault mkMerge concatStringsSep;
  inherit (lib.attrsets) getAttrs;
  inherit (flake.lib) mkNetworkHostServiceModule mkSharedSecrets mkGroupsFromSecretsWithMembers;
  inherit (config.lib.network) getServiceVariables;

  inherit
    (getServiceVariables "librechat")
    serviceName
    portName
    networkCfg
    cfg
    ports
    ;

  # Turn a secret name into a shell-safe env var name (LibreChat exports each
  # credential via `export <name>=...`, so it must be a valid identifier).
  toEnvVar = replaceStrings ["/" "-" "."] ["_" "_" "_"];
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({name, ...}: {
      configEnable.ports.${portName} = {
        protocol = "http";
        port = mkDefault 3080;
      };

      provideEnable.oidc-clients = [
        rec {
          secrets = mkSharedSecrets [clientSecretName] ./secrets.yaml;
          clientId = "librechat";
          clientName = "LibreChat";
          hashedClientSecret = "$pbkdf2-sha512$310000$v3IyMCC9JJDTjzMPQ8UQeQ$YI3HawEirlKEWUvjk0.WIBxbqP1hnaneJrQzVP9S9fIvfT/xhYxvpR9yh7/HfJSxdfw5N3kx9yvRKVyPbnZm3Q";
          clientSecretName = "librechat/oidc-secret";
          redirectUris = let
            getAddress = config.lib.network.getAddress {
              hostName = name;
              portName = serviceName;
            };
          in [getAddress "https://<domain>/oauth/openid/callback"];
          scopes = ["openid" "profile" "email"];
          public = false;
          pkce.enabled = false;
          endpointAuthMethod = "client_secret_post";
        }
      ];
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    # base service + always-on secrets
    {
      sops.secrets = {
        "librechat/creds_key" = {
          sopsFile = ./secrets.yaml;
          owner = config.services.librechat.user;
        };
        "librechat/creds_iv" = {
          sopsFile = ./secrets.yaml;
          owner = config.services.librechat.user;
        };
        "librechat/jwt_secret" = {
          sopsFile = ./secrets.yaml;
          owner = config.services.librechat.user;
        };
        "librechat/jwt_refresh_secret" = {
          sopsFile = ./secrets.yaml;
          owner = config.services.librechat.user;
        };
      };
      services.librechat = {
        enable = true;
        enableLocalDB = true;
        env = {
          HOST = "0.0.0.0";
          PORT = ports.${portName}.port;
          TRUST_PROXY = 2;
          DOMAIN_SERVER = ports.${portName}.getAddress "https://<domain>";
          DOMAIN_CLIENT = ports.${portName}.getAddress "https://<domain>";
        };
        credentials = {
          CREDS_KEY = config.getSopsFile "librechat/creds_key";
          CREDS_IV = config.getSopsFile "librechat/creds_iv";
          JWT_SECRET = config.getSopsFile "librechat/jwt_secret";
          JWT_REFRESH_SECRET = config.getSopsFile "librechat/jwt_refresh_secret";
        };
        settings.version = mkDefault "1.3.5";
      };
    }

    # OPENAI-API INTEGRATION (any OpenAI-compatible provider)
    (let
      openaiApi = cfg.require.openai-api;
      apiSecret = getAttrs [openaiApi.apiKeySecretName] openaiApi.secrets;
      envVar = toEnvVar openaiApi.apiKeySecretName;
    in
      mkIf (openaiApi != null) {
        # value-identical to the provider's own registration when on the same host
        sops.secrets = apiSecret;
        users.groups = mkGroupsFromSecretsWithMembers apiSecret [config.services.librechat.user];
        services.librechat = {
          credentials.${envVar} = config.getSopsFile openaiApi.apiKeySecretName;
          settings.endpoints.custom = [
            {
              name = openaiApi.displayName;
              apiKey = "\${${envVar}}";
              baseURL = openaiApi.url;
              models = {
                default = ["any"];
                fetch = true;
              };
              titleConvo = true;
              modelDisplayLabel = openaiApi.displayName;
            }
          ];
        };
      })

    # OIDC INTEGRATION (authelia as oidc-server)
    (let
      oidcServer = cfg.require.oidc-server;
      oidcClient = head cfg.provide.oidc-clients;
      clientSecret = getAttrs [oidcClient.clientSecretName] oidcClient.secrets;
    in
      mkIf (oidcServer != null) {
        sops.secrets =
          clientSecret
          // {
            "librechat/session_secret" = {
              sopsFile = ./secrets.yaml;
              owner = config.services.librechat.user;
            };
          };
        users.groups = mkGroupsFromSecretsWithMembers clientSecret [config.services.librechat.user];
        services.librechat = {
          env = {
            ALLOW_SOCIAL_LOGIN = true;
            OPENID_BUTTON_LABEL = "Login with ${oidcServer.name}";
            OPENID_ISSUER = oidcServer.getAddress "https://<domain>/.well-known/openid-configuration";
            OPENID_CLIENT_ID = oidcClient.clientId;
            OPENID_CALLBACK_URL = "/oauth/openid/callback";
            OPENID_SCOPE = concatStringsSep " " oidcClient.scopes;
            OPENID_IMAGE_URL = "https://www.authelia.com/images/branding/logo-cropped.png";
            OPENID_NAME_CLAIM = "preferred_username";
          };
          credentials.OPENID_CLIENT_SECRET = config.getSopsFile oidcClient.clientSecretName;
          credentials.OPENID_SESSION_SECRET = config.getSopsFile "librechat/session_secret";
        };
      })
  ]);
}
