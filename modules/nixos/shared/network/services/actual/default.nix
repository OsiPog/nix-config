{
  config,
  lib,
  flake,
  ...
}: let
  inherit (builtins) head;
  inherit (lib) mkIf mkDefault mkMerge;
  inherit (lib.attrsets) getAttrs;
  inherit (flake.lib) mkNetworkHostServiceModule mkGroupsFromSecretsWithMembers mkSharedSecrets;
  inherit (config.lib.network) getServiceVariables;

  inherit
    (getServiceVariables "actual")
    serviceName
    portName
    networkCfg
    cfg
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({cfg, ...}: {
      provideEnable = {
        ports.${portName} = {
          protocol = "http";
          port = mkDefault 3000;
        };

        oidc-clients = [
          rec {
            secrets = mkSharedSecrets [clientSecretName] ./secrets.yaml;
            clientId = "actual";
            clientName = "Actual Budget";
            hashedClientSecret = "$pbkdf2-sha512$310000$tw6ED7vMohjuwO/tGM.lwA$a4QLPEcRC/EIwxqvIravhn7LSxwKmEM9.s1uTqn1Ud2S1gzA0Sc20ZOry4M4gEvpy0X5eqZJHLGBGoj1/drFZw";
            clientSecretName = "actual/oidc-secret";
            redirectUris = [(cfg.provide.ports.${portName}.getAddress "https://<domain>/openid/callback")];
            scopes = ["openid" "profile" "email" "groups"];
            public = false;
            pkce.enabled = false;
          }
        ];
      };
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    {
      services.actual = {
        enable = true;
        settings.port = cfg.provide.ports.${portName}.port;
      };
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
          templates.actual-env = {
            content = ''
              ACTUAL_OPENID_CLIENT_SECRET=${config.sops.placeholder.${oidcClient.clientSecretName}}
            '';
            owner = config.services.actual.user;
          };
        };
        users.groups = mkGroupsFromSecretsWithMembers secrets [config.services.vikunja.database.user];
        # for the client secret
        systemd.services.actual.serviceConfig.EnvironmentFile = config.sops.templates.actual-env.path;

        services.actual.settings.openId = {
          discoveryURL = oidcServer.getAddress "https://<domain>";
          client_id = oidcClient.clientId;
          server_hostname = cfg.provide.ports.${portName}.getAddress "https://<domain>";
          authMethod = "oauth2";
        };
      })
  ]);
}
