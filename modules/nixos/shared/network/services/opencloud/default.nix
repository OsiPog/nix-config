{
  config,
  lib,
  flake,
  hostName,
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
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      configEnable.ports.${portName} = {
        protocol = "https";
        port = mkDefault 9200;
      };
      provideEnable.ldap-clients = [{groups.cloud = {};}];
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    {
      services.opencloud = {
        inherit stateDir;
        enable = true;
        address = "0.0.0.0";
        port = ports.opencloud.port;
        url = address "protocol://domain";
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
          OC_LDAP_URI = ldapServer.address "protocol://domain:port";
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
  ]);
}
