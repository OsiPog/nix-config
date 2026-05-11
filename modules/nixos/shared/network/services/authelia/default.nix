{
  config,
  lib,
  flake,
  hostName,
  ...
}: let
  inherit (lib) mkIf mkMerge mkDefault;
  inherit (lib.attrsets) getAttrs;

  inherit (flake.lib) mkNetworkHostServiceModule mkGroupsFromSecretsWithMembers;
  inherit (config.lib.network) getAddress getServiceVariables;

  inherit
    (getServiceVariables "authelia")
    serviceName
    portName
    networkCfg
    cfg
    ports
    ;

  stateDir = "/var/lib/authelia-default";
  address = getAddress {
    inherit hostName;
    portName = "authelia";
  };
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      configEnable.ports.${portName} = {
        protocol = "https";
        port = 9091;
      };
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    {
      assertions = [
        {
          assertion = ports.authelia.reverseProxy.enable;
          message = "Authelia needs to be reverse proxied as https is required.";
        }
      ];

      # Authelia secrets
      sops.secrets = {
        "authelia/jwtSecret" = {
          owner = config.services.authelia.instances.default.user;
          sopsFile = ./secrets.yaml;
        };
        "authelia/storageEncryptionKey" = {
          owner = config.services.authelia.instances.default.user;
          sopsFile = ./secrets.yaml;
        };
        "authelia/oidcIssuerPrivateKeyFile" = {
          owner = config.services.authelia.instances.default.user;
          sopsFile = ./secrets.yaml;
        };
      };

      # Authelia service configuration
      services.authelia.instances.default = {
        enable = true;
        secrets = {
          jwtSecretFile = config.getSopsFile "authelia/jwtSecret";
          storageEncryptionKeyFile = config.getSopsFile "authelia/storageEncryptionKey";
          oidcIssuerPrivateKeyFile = config.getSopsFile "authelia/oidcIssuerPrivateKeyFile";
        };
        settings = {
          server.address = "tcp://:${toString ports.${portName}.port}";
          log.level = "info";
          storage.local.path = "${stateDir}/db.sqlite3";
          session.cookies = [
            {
              domain = address "domain";
              authelia_url = address "proxyProtocol://domain";
            }
          ];
          access_control.default_policy = "two_factor";
        };
      };
    }

    # LDAP INTEGRATION
    (let
      ldapServer = cfg.require.ldap-server;
      secrets = getAttrs [ldapServer.users.manage.secretName] ldapServer.secrets;
    in
      mkIf (ldapServer != null) {
        sops = {inherit secrets;};
        users.groups = mkGroupsFromSecretsWithMembers secrets [config.services.authelia.instances.default.user];
        services.authelia.instances.default = {
          environmentVariables.AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE = config.getSopsFile ldapServer.users.manage.secretName;
          settings.authentication_backend = {
            refresh_interval = mkDefault "1m";
            ldap = {
              implementation = "lldap";
              address = ldapServer.address "proxyProtocol://domain:port";
              base_dn = ldapServer.baseDN;
              user = "uid=${ldapServer.users.manage.dn},ou=people,${ldapServer.baseDN}";
            };
          };
        };
      })
  ]);
}
