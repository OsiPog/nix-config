{
  config,
  lib,
  flake,
  ...
}: let
  inherit (builtins) head;
  inherit (lib) mkIf mkForce mkDefault mkMerge;
  inherit (lib.attrsets) getAttrs;
  inherit (flake.lib) mkNetworkHostServiceModule mkGroupsFromSecretsWithMembers mkSharedSecrets;
  inherit (config.lib.network) getServiceVariables;

  inherit
    (getServiceVariables "mealie")
    serviceName
    portName
    networkCfg
    cfg
    ports
    stateDir
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({name, ...}: {
      configEnable.ports.${portName} = {
        protocol = "http";
        port = mkDefault 9000;
      };

      provideEnable.backup-paths = [{path = stateDir;}];

      provideEnable.oidc-clients = [
        rec {
          secrets = mkSharedSecrets [clientSecretName] ./secrets.yaml;
          clientId = "mealie";
          clientName = "Mealie";
          hashedClientSecret = "$pbkdf2-sha512$310000$Idxsql8lKgSLmKJObbe6.A$3fzRS8rt3/.ZaZs.wj7twZMmhIlAiDryqPx.LO8prLVZQnVzCXiB.rcKEsBr6V6Nq/eNSAG3q4EonsqTdjBldA";
          clientSecretName = "mealie/oidc-secret";
          redirectUris = let
            getAddress = config.lib.network.getAddress {
              hostName = name;
              portName = serviceName;
            };
          in [getAddress "https://<domain>/login"];
          scopes = ["openid" "email" "profile" "groups"];
          public = false;
          pkce.enabled = true;
          pkce.method = "S256";
        }
      ];
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    {
      services.mealie = {
        enable = true;
        port = ports.${portName}.port;
        settings.BASE_URL = ports.${portName}.getAddress "https://<domain>";
      };

      # static user so the raw oidc client secret can be group-owned (no DynamicUser)
      systemd.services.mealie.serviceConfig = {
        DynamicUser = mkForce false;
        User = "mealie";
        Group = "mealie";
      };
      users.users.mealie = {
        isSystemUser = true;
        group = "mealie";
      };
      users.groups.mealie = {};
    }

    # OIDC SERVER INTEGRATION
    (let
      oidcServer = cfg.require.oidc-server;
      oidcClient = head cfg.provide.oidc-clients;
      secrets = getAttrs [oidcClient.clientSecretName] oidcClient.secrets;
    in
      mkIf (oidcServer != null) {
        sops = {
          inherit secrets;
          templates.mealie-env = {
            content = ''
              OIDC_CLIENT_SECRET=${config.sops.placeholder.${oidcClient.clientSecretName}}
            '';
            owner = "mealie";
          };
        };
        users.groups = mkGroupsFromSecretsWithMembers secrets ["mealie"];
        services.mealie.credentialsFile = config.sops.templates.mealie-env.path;

        services.mealie.settings = {
          OIDC_AUTH_ENABLED = "true";
          OIDC_SIGNUP_ENABLED = "true";
          OIDC_AUTO_REDIRECT = "false";
          OIDC_CONFIGURATION_URL = oidcServer.getAddress "https://<domain>/.well-known/openid-configuration";
          OIDC_CLIENT_ID = oidcClient.clientId;
          OIDC_ADMIN_GROUP = oidcServer.adminGroup;
          OIDC_PROVIDER_NAME = oidcServer.name;
          ALLOW_PASSWORD_LOGIN = "false";
        };
      })
  ]);
}
