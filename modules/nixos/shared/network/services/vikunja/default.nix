{
  config,
  lib,
  flake,
  ...
}: let
  inherit (builtins) head concatStringsSep;
  inherit (lib) mkIf mkDefault mkMerge;
  inherit (lib.attrsets) getAttrs;
  inherit (flake.lib) mkNetworkHostServiceModule mkGroupsFromSecretsWithMembers mkSharedSecrets;
  inherit (config.lib.network) getServiceVariables;

  inherit
    (getServiceVariables "vikunja")
    serviceName
    portName
    networkCfg
    cfg
    ports
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      configEnable = {
        ports.${portName} = {
          protocol = "http";
          port = mkDefault 3456;
        };
      };

      provideEnable = {
        oidc-clients = [
          rec {
            secrets = mkSharedSecrets [clientSecretName] ./secrets.yaml;
            clientId = "vikunja";
            clientName = "Vikunja";
            hashedClientSecret = "$pbkdf2-sha512$310000$baAB81Q4y84KbUg3Jec0lQ$70yiYI0PsFXxD74Is0u1R4bIgS8BeYEXN7zlSe1YmROyjsQ/Z9iGDKnez.HlyIbHXSmk64AoAClOZepm4Yct0A";
            clientSecretName = "vikunja/oidc-secret";
            redirectUris = ["${ports.${portName}.address "proxyProtocol://domain"}/auth/openid/oidc"];
            scopes = ["openid" "profile" "email"];
            public = false;
            pkce.enabled = false;
            idTokenClaims = ["email" "preferred_username"];
          }
        ];
      };
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    {
      services.vikunja = {
        enable = true;
        port = ports.${portName}.port;
        frontendScheme = "https";
        frontendHostname = ports.${portName}.address "domain";
      };
    }

    # OIDC SERVER INTEGRATION
    (let
      oidcServer = cfg.require.oidc-server;
      oidcClient = head cfg.provide.oidc-clients;
      secrets = getAttrs [oidcClient.clientSecretName] oidcClient.secrets;
    in
      mkIf (oidcServer != null) {
        sops = {inherit secrets;};
        users.groups = mkGroupsFromSecretsWithMembers secrets [config.services.vikunja.database.user];
        services.vikunja.settings = {
          service.enableregistration = false; # oidc server handles users so we disable this
          auth.openid = {
            enabled = true;
            providers.oidc = {
              name = "Single-Sign-On";
              authurl = oidcServer.address "proxyProtocol://domain";
              clientid = oidcClient.clientId;
              clientsecret.file = config.getSopsFile oidcClient.clientSecretName;
              scope = concatStringsSep " " oidcClient.scopes;
            };
          };
        };
      })
  ]);
}
