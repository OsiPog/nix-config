{
  config,
  lib,
  flake,
  hostName,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkMerge mkDefault;
  inherit (lib.attrsets) filterAttrs;
  inherit (flake.lib) mkNetworkHostServiceModule mkGroupsFromSecretsWithMembers;
  inherit (config.lib.network) getServiceVariables getAddress;

  inherit
    (getServiceVariables "opencloud")
    serviceName
    networkCfg
    cfg
    ports
    portName
    stateDir
    ;
  address = getAddress {
    inherit portName;
    inherit hostName;
  };
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({name, ...}: {
      configEnable.ports.${portName} = {
        protocol = "http";
        port = mkDefault 9200;
      };
      provideEnable.ldap-clients = [{groups.cloud = {};}];
      provideEnable.oidc-clients = let
        ocAddress = getAddress {
          hostName = name;
          portName = serviceName;
        };
        baseUrl = ocAddress "proxyProtocol://domain";
      in [
        {
          clientId = "web";
          clientName = "OpenCloud Web";
          redirectUris = [
            "${baseUrl}/"
            "${baseUrl}/oidc-callback.html"
            "${baseUrl}/oidc-silent-redirect.html"
          ];
          public = true;
          pkce = {
            enabled = true;
            method = "S256";
          };
        }
        {
          clientId = "OpenCloudDesktop";
          clientName = "OpenCloud Desktop";
          redirectUris = ["http://127.0.0.1" "http://localhost"];
          public = true;
          pkce = {
            enabled = true;
            method = "S256";
          };
        }
        {
          clientId = "OpenCloudAndroid";
          clientName = "OpenCloud Android";
          redirectUris = ["oc://android.opencloud.eu"];
          public = true;
          pkce = {
            enabled = true;
            method = "S256";
          };
        }
        {
          clientId = "OpenCloudIOS";
          clientName = "OpenCloud iOS";
          redirectUris = ["oc://ios.opencloud.eu"];
          public = true;
          pkce = {
            enabled = true;
            method = "S256";
          };
        }
        {
          clientId = "Cyberduck";
          clientName = "Cyberduck";
          redirectUris = [
            "x-cyberduck-action:oauth"
            "x-mountainduck-action:oauth"
          ];
          public = true;
          pkce = {
            enabled = true;
            method = "S256";
          };
        }
      ];
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    {
      services.opencloud = {
        inherit stateDir;
        enable = true;
        address = "0.0.0.0";
        port = ports.opencloud.port;
        url = address "proxyProtocol://domain";
        environment = {
          PROXY_TLS = "false"; # TLS handled by reverse proxy
        };
        # settings = {
        #   proxy.proxy.http.tls = false;
        # };
      };
    }

    # LDAP INTEGRATION
    (let
      ldapServer = cfg.require.ldap-server;
      secrets = filterAttrs (name: _: name == ldapServer.users.search.secretName) ldapServer.secrets;
    in
      mkIf (ldapServer != null) {
        sops = {
          inherit secrets;
          templates.opencloud-env = {
            content = ''
              OC_LDAP_BIND_PASSWORD=${config.sops.placeholder.${ldapServer.users.search.secretName}}
            '';
            owner = "opencloud";
          };
        };
        users.groups = mkGroupsFromSecretsWithMembers secrets [config.services.opencloud.user];
        services.opencloud.environment = {
          OC_LDAP_URI = ldapServer.address "proxyProtocol://domain:port";
          OC_LDAP_BIND_DN = "uid=${ldapServer.users.search.dn},ou=people,${ldapServer.baseDN}";
          OC_ADMIN_USER_ID = ldapServer.users.admin.dn;

          OC_LDAP_USER_BASE_DN = "ou=people,${ldapServer.baseDN}";
          OC_LDAP_USER_FILTER = "(|(memberof=cn=cloud,ou=groups,${ldapServer.baseDN})(uid=${ldapServer.users.admin.dn}))";
          OC_LDAP_USER_ENABLED_ATTRIBUTE = "uid";
          OC_LDAP_USER_SCHEMA_ID = "uid";
          OC_LDAP_USER_SCHEMA_USER_TYPE = "";
          OC_LDAP_CACERT = config.security.pki.caBundle;

          OC_LDAP_GROUP_BASE_DN = "ou=groups,${ldapServer.baseDN}";
          OC_LDAP_GROUP_SCHEMA_ID = "uid";
          OC_LDAP_GROUP_SCHEMA_MAIL = "";

          OC_LDAP_SERVER_WRITE_ENABLED = "false";
        };

        systemd.services.opencloud.serviceConfig.EnvironmentFile = [config.sops.templates.opencloud-env.path];
      })

    # OIDC SERVER INTEGRATION
    (let
      oidcServer = cfg.require.oidc-server;
      serverAddress = oidcServer.address "proxyProtocol://domain";
    in
      mkIf (oidcServer != null) {
        services.opencloud = {
          environment = {
            OC_OIDC_ISSUER = serverAddress;
            PROXY_OIDC_REWRITE_WELLKNOWN = "true";
            PROXY_USER_OIDC_CLAIM = "preferred_username";
            PROXY_USER_CS3_CLAIM = "username";
            PROXY_ROLE_ASSIGNMENT_DRIVER = "default";
            PROXY_OIDC_ACCESS_TOKEN_VERIFY_METHOD = "none";
            GRAPH_ASSIGN_DEFAULT_USER_ROLE = "false";

            PROXY_CSP_CONFIG_FILE_LOCATION = toString (pkgs.writeTextFile {
              name = "csp.yaml";
              text =
                /*
                yaml
                */
                ''
                  directives:
                    connect-src: ['${serverAddress}/']
                '';
            });
          };
        };
      })
  ]);
}
