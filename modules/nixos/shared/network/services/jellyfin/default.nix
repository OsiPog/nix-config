{
  config,
  lib,
  pkgs,
  flake,
  hostName,
  ...
}: let
  inherit (lib) mkIf mkMerge mkDefault;
  inherit (lib.attrsets) filterAttrs;
  inherit (flake.lib) mkNetworkHostServiceModule mkGroupsFromSecretsWithMembers;
  inherit (config.lib.network) getServiceVariables getAddress;

  inherit
    (getServiceVariables "jellyfin")
    serviceName
    portName
    networkCfg
    stateDir
    cfg
    ;

  address = getAddress {
    inherit portName;
    inherit hostName;
  };
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      configEnable = {
        ports.${portName} = {
          protocol = "https";
          port = mkDefault 8096;
        };
      };
      provideEnable.ldap-clients = [{groups.media = {};}];
    }))

    flake.inputs.jellarr.nixosModules.default
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    {
      sops = {
        secrets = {
          "jellyfin/admin-pass" = {
            owner = config.services.jellyfin.user;
            sopsFile = ./secrets.yaml;
          };
          "jellyfin/api-key" = {
            owner = config.services.jellyfin.user;
            sopsFile = ./secrets.yaml;
          };
        };
        templates.jellarr-env = {
          content = ''
            JELLARR_API_KEY=${config.sops.placeholder."jellyfin/api-key"}
          '';
          owner = config.services.jellyfin.user;
        };
      };

      services.jellyfin = {
        enable = true;
        dataDir = stateDir;
      };

      services.jellarr = {
        enable = true;
        environmentFile = config.sops.templates.jellarr-env.path;
        inherit (config.services.jellyfin) user group;
        dataDir = "${stateDir}/jellarr";
        bootstrap = {
          enable = true;
          apiKeyFile = config.getSopsFile "jellyfin/api-key";
        };
        config = {
          version = mkDefault 1;
          base_url = address "protocol://domain";
          system = {};
          startup.completeStartupWizard = true;
          users = [
            {
              name = "jellyfin-admin";
              passwordFile = config.getSopsFile "jellyfin/admin-pass";
              policy = {
                isAdministrator = true;
                loginAttemptsBeforeLockout = 3;
              };
            }
          ];
        };
      };
    }

    # LDAP INTEGRATION
    (let
      ldapServer = cfg.require.ldap-server;
      secrets = filterAttrs (name: _: name == ldapServer.users.search.secretName) ldapServer.secrets;
    in
      mkIf (ldapServer != null) {
        sops = {inherit secrets;};
        users.groups = mkGroupsFromSecretsWithMembers secrets [config.services.jellyfin.user];
        services.jellarr.config = {
          system.pluginRepositories = [
            {
              name = "Jellyfin Official";
              url = "https://repo.jellyfin.org/releases/plugin/manifest.json";
              enabled = true;
            }
          ];
          plugins = [
            {
              name = "LDAP Authentication";
              configuration = {
                LdapServer = ldapServer.address "domain";
                LdapPort = 6360;

                LdapAdminBaseDn = ldapServer.baseDN;
                LdapAdminFilter = "(uid=${ldapServer.users.admin.dn})";

                LdapBaseDn = ldapServer.baseDN;
                LdapBindUser = "uid=${ldapServer.users.search.dn},ou=people,${ldapServer.baseDN}";
                LdapPasswordAttribute = ldapServer.attributes.password;
                LdapProfileImageAttribute = ldapServer.attributes.icon;
                LdapProfileImageFormat = "Default";
                LdapSearchAttributes = "uid,cn,mail,displayName";
                LdapSearchFilter = "(|(memberof=cn=media,ou=groups,${ldapServer.baseDN})(uid=${ldapServer.users.admin.dn}))";
                LdapUidAttribute = ldapServer.attributes.uid;
                LdapUsernameAttribute = "cn";

                UseSsl = true;

                AllowPassChange = false;
                CreateUsersFromLdap = true;
                EnableLdapProfileImageSync = true;
              };
            }
          ];
        };
        systemd.services.jellarr-set-ldap-bind-password = {
          after = ["jellarr.service" "jellyfin.service"];
          wantedBy = ["multi-user.target"];
          path = [pkgs.curl];
          serviceConfig.Type = "oneshot";
          script = ''
            curl ${config.services.jellarr.config.base_url}/Plugins/958aad6637844d2ab89aa7b6fab6e25c/Configuration \
              -X POST \
              -H "Content-Type: application/json" \
              -H "X-Emby-Token: $(cat ${config.services.jellarr.bootstrap.apiKeyFile})" \
              --data "{\"LdapBindPassword\": \"$(cat ${config.getSopsFile ldapServer.users.search.secretName})\"}"
          '';
        };
      })
  ]);
}
