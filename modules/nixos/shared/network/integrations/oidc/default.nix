{
  config,
  flake,
  lib,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  inherit (flake.lib) mkNetworkHostServiceIntegrationModule;
  inherit (config.lib.network) getIntegrationVariables getAddress;

  inherit
    (getIntegrationVariables "oidc" ["headscale"])
    integrationName
    integratedServices
    networkCfg
    hostSrvs
    serviceWithIntegrationEnable
    serviceWithIntegrationEnabledAnywhere
    ;
in {
  imports = [
    (mkNetworkHostServiceIntegrationModule {
        inherit integrationName integratedServices;
        serviceName = "authelia";
        portName = "authelia";
        protocol = "https";
      }
      null)
  ];

  # authelia note: generate clients secrets with:
  # nix run nixpkgs#authelia -- crypto hash generate pbkdf2 --variant sha512 --random --random.length 72 --random.charset rfc3986

  config = mkIf networkCfg.enable (mkMerge [
    # --- HEADSCALE
    (mkIf (serviceWithIntegrationEnabledAnywhere "headscale") (mkMerge [
      # configure headscale with client secret
      (mkIf (serviceWithIntegrationEnable "headscale") {
        sops.secrets."headscale/oidc-secret" = {
          sopsFile = ./headscale.yaml;
          owner = config.services.headscale.user;
        };

        services.headscale.settings.oidc = {
          issuer = hostSrvs.headscale.integrations.oidc.address;
          client_id = "headscale";
          client_secret_path = config.getSopsFile "headscale/oidc-secret";
          scope = ["openid" "profile" "email" "groups"];
          pkce = {
            enabled = true;
            method = "S256";
          };
        };
      })

      # authelia configuration
      (mkIf hostSrvs.authelia.enable {
        services.authelia.instances.default.settings.identity_providers.oidc = {
          claims_policies.headscale.id_token = ["email" "groups"];
          clients = [
            {
              client_id = "headscale";
              client_name = "Headscale";
              client_secret = "$pbkdf2-sha512$310000$OM.pbqoXjN0sV3ePThP93A$DqJvD5pH5D65CC48UVV2amlinmsQN078kWapJWtn4JUr369PHh/Ce/0TZyx1gbFcOBeFo2Kr8IkUvkQx2fwUYQ";
              claims_policy = "headscale";
              public = false;
              require_pkce = true;
              pkce_challenge_method = "S256";
              redirect_uris = [
                "${getAddress {
                  protocol = "https";
                  portName = "headscale";
                }}/oidc/callback"
              ];
              scopes = ["openid" "email" "profile" "groups"];
              response_types = ["code"];
              grant_types = ["authorization_code"];
              access_token_signed_response_alg = "none";
              userinfo_signed_response_alg = "none";
              token_endpoint_auth_method = "client_secret_basic";
            }
          ];
        };
      })
    ]))
  ]);
}
