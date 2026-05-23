{
  config,
  hostName,
  lib,
  flake,
  ...
}: let
  inherit (builtins) toFile toJSON head;
  inherit (lib) mkIf mkDefault mkMerge mkForce mkBefore;
  inherit (lib.attrsets) getAttrs;
  inherit (flake.lib) mkNetworkHostServiceModule mkSharedSecrets mkGroupsFromSecretsWithMembers;
  inherit (config.lib.network) getAddress getServiceVariables;

  inherit
    (getServiceVariables "headscale")
    serviceName
    portName
    networkCfg
    cfg
    ports
    ;

  stateDir = "/var/lib/headscale"; # hardcoded in nixpkgs, not configurable

  tailscaleServer = cfg.provide.tailscale-server;
in {
  imports = [
    (mkNetworkHostServiceModule {
        inherit serviceName;
        enforceSingleInstance = true;
      } ({name, ...}: {
        configEnable = {
          ports.headscale = {
            protocol = "http";
            port = mkDefault 8081;
          };
        };
        provideEnable = {
          tailscale-server = rec {
            secrets = mkSharedSecrets [authKeySecretName] ./secrets.yaml;
            address = getAddress {
              portName = "headscale";
              hostName = name;
            };
            ip4Space = "100.64.0.0/10";
            authKeySecretName = "headscale/auth-key";
          };

          oidc-clients = [
            rec {
              secrets = mkSharedSecrets [clientSecretName] ./secrets.yaml;
              clientId = "headscale";
              clientName = "Headscale";
              hashedClientSecret = "$pbkdf2-sha512$310000$OM.pbqoXjN0sV3ePThP93A$DqJvD5pH5D65CC48UVV2amlinmsQN078kWapJWtn4JUr369PHh/Ce/0TZyx1gbFcOBeFo2Kr8IkUvkQx2fwUYQ";
              clientSecretName = "headscale/oidc-secret";
              redirectUris = let
                address = getAddress {
                  hostName = name;
                  portName = serviceName;
                };
              in ["${address "proxyProtocol://domain"}/oidc/callback"];
              scopes = ["openid" "profile" "email" "groups"];
              pkce = {
                enabled = true;
                method = "S256";
              };
              idTokenClaims = ["email" "groups"];
            }
          ];
        };
      }))
  ];
  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    {
      services.headscale = {
        enable = true;
        address = "0.0.0.0";
        port = ports.${serviceName}.port;
        settings = {
          # allow all policy
          policy.path = toFile "file.json" (toJSON {});
          server_url = tailscaleServer.address "proxyProtocol://domain";
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
            base_domain = "dns." + (tailscaleServer.address "domain");
          };
        };
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
        users.groups = mkGroupsFromSecretsWithMembers secrets [config.services.headscale.user];
        services.headscale.settings.oidc = {
          only_start_if_oidc_is_available = mkDefault false;
          issuer = oidcServer.address "proxyProtocol://domain";
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
      dnsServer = cfg.require.dns-server;
    in
      mkIf (dnsServer != null) {
        services.headscale.settings.dns.nameservers.global = [(dnsServer.address "ip")];
      })
  ]);
}
