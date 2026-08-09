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
    networkCfg
    cfg
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({cfg, ...}: {
      provideEnable = {
        ports.http = {
          protocol = "http";
          port = mkDefault 3456;
        };

        mail-clients = [
          rec {
            secrets = mkSharedSecrets [mailAccount.secretName] ./secrets.yaml;
            mailAccount = {
              uid = "vikunja-mail";
              email = "noreply.vikunja@${cfg.require.mail-server.getAddress "<domain>"}";
              display = "Vikunja";
              secretName = "vikunja/mail-pass";
            };
          }
        ];

        oidc-clients = [
          rec {
            secrets = mkSharedSecrets [clientSecretName] ./secrets.yaml;
            clientId = "vikunja";
            clientName = "Vikunja";
            hashedClientSecret = "$pbkdf2-sha512$310000$baAB81Q4y84KbUg3Jec0lQ$70yiYI0PsFXxD74Is0u1R4bIgS8BeYEXN7zlSe1YmROyjsQ/Z9iGDKnez.HlyIbHXSmk64AoAClOZepm4Yct0A";
            clientSecretName = "vikunja/oidc-secret";
            redirectUris = [(cfg.provide.ports.http.getAddress "https://<domain>/auth/openid/oidc")];
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
        port = cfg.provide.ports.http.port;
        frontendScheme = "https";
        frontendHostname = cfg.provide.ports.http.getAddress "<domain>";
      };
    }

    # MAIL SERVER INTEGRATION
    (let
      mailServer = cfg.require.mail-server;
      mailClient = head cfg.provide.mail-clients;
      secrets = getAttrs [mailClient.mailAccount.secretName] mailClient.secrets;
    in
      mkIf (mailServer != null) {
        sops = {inherit secrets;};
        users.groups = mkGroupsFromSecretsWithMembers secrets [config.services.vikunja.database.user];
        services.vikunja.settings.mailer = {
          enabled = true;
          host = mailServer.getAddress "<domain>";
          port = mailServer.getAddress "<port>";
          forcessl = true;
          username = mailClient.mailAccount.email;
          fromemail = mailClient.mailAccount.email;
          password.file = config.getSopsFile mailClient.mailAccount.secretName;
        };
      })

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
              inherit (oidcServer) name;
              authurl = oidcServer.getAddress "https://<domain>";
              clientid = oidcClient.clientId;
              clientsecret.file = config.getSopsFile oidcClient.clientSecretName;
              scope = concatStringsSep " " oidcClient.scopes;
            };
          };
        };
      })
  ]);
}
