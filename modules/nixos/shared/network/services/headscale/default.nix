{
  config,
  hostName,
  lib,
  flake,
  ...
}: let
  inherit (builtins) toFile toJSON;
  inherit (lib) mkIf mkDefault mkMerge mkForce mkBefore;
  inherit (lib.attrsets) getAttrs genAttrs;
  inherit (flake.lib) mkNetworkHostServiceModule mkSharedSecrets mkGroupsFromSecretsWithMembers nixosHostNames headAttrs;
  inherit (config.lib.network) getServiceVariables;

  inherit
    (getServiceVariables "headscale")
    serviceName
    networkCfg
    cfg
    ;

  stateDir = "/var/lib/headscale"; # hardcoded in nixpkgs, not configurable

  tailscaleServer = cfg.provide.tailscale-servers.${serviceName};
in {
  imports = [
    (mkNetworkHostServiceModule {
        inherit serviceName;
        enforceSingleInstance = true;
      } ({cfg, ...}: {
        provideEnable = {
          ports.http = {
            protocol = "http";
            port = mkDefault 8081;
          };
          backup-paths.${serviceName} = {path = stateDir;};
          tailscale-servers.${serviceName} = let
            authKeySecretName = "headscale/auth-key";
          in {
            secrets = mkSharedSecrets [authKeySecretName] ./secrets.yaml;
            getAddress = cfg.provide.ports.http.getAddress;
            ip4Space = "100.64.0.0/10";
            inherit authKeySecretName;
          };

          oidc-clients.${serviceName} = rec {
            secrets = mkSharedSecrets [clientSecretName] ./secrets.yaml;
            clientId = "headscale";
              clientName = "Headscale";
              hashedClientSecret = "$pbkdf2-sha512$310000$OM.pbqoXjN0sV3ePThP93A$DqJvD5pH5D65CC48UVV2amlinmsQN078kWapJWtn4JUr369PHh/Ce/0TZyx1gbFcOBeFo2Kr8IkUvkQx2fwUYQ";
              clientSecretName = "headscale/oidc-secret";
              redirectUris = [(cfg.provide.ports.http.getAddress "https://<domain>/oidc/callback")];
              scopes = ["openid" "profile" "email" "groups"];
              pkce = {
                enabled = true;
                method = "S256";
              };
              idTokenClaims = ["email" "groups"];
          };
        };
      }))

    flake.nixosModules.headscaleDeclarativePolicy
  ];
  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    {
      services.headscale = {
        enable = true;
        address = "0.0.0.0";
        port = cfg.provide.ports.http.port;
        policy.hosts = genAttrs nixosHostNames (hostName: networkCfg.hosts.${hostName}.vpn.ip + "/32");
        settings = {
          server_url = tailscaleServer.getAddress "https://<domain>";
          dns = {
            override_local_dns = true;
            nameservers.global = mkDefault [
              "1.1.1.1"
              "1.0.0.1"
              "2606:4700:4700::1111"
              "2606:4700:4700::1001"
            ];
            # Magic DNS
            magic_dns = true;
            base_domain = "dns." + (tailscaleServer.getAddress "<domain>");
          };
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
        sops = {inherit secrets;};
        users.groups = mkGroupsFromSecretsWithMembers secrets [config.services.headscale.user];
        services.headscale.settings.oidc = {
          only_start_if_oidc_is_available = mkDefault false;
          issuer = oidcServer.getAddress "https://<domain>";
          client_id = oidcClient.clientId;
          client_secret_path = config.getSopsFile oidcClient.clientSecretName;
          scope = oidcClient.scopes;
          pkce = {
            enabled = oidcClient.pkce.enabled;
            method = oidcClient.pkce.method;
          };
        };
      })

    # DNS SERVER
    (let
      dnsServer = headAttrs cfg.require.dns-servers;
    in
      mkIf (cfg.require.dns-servers != {}) {
        services.headscale.settings.dns.nameservers.global = [(dnsServer.getAddress "<ip>")];
      })
  ]);
}
