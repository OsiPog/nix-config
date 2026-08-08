{
  config,
  lib,
  flake,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkDefault mkMerge;
  inherit (lib.attrsets) filterAttrs;
  inherit (flake.lib) mkNetworkHostServiceModule mkGroupsFromSecretsWithMembers;
  inherit (config.lib.network) getServiceVariables;

  inherit
    (getServiceVariables "home-assistant")
    serviceName
    portName
    networkCfg
    cfg
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      provideEnable = {
        ports.${portName} = {
          protocol = "http";
          port = mkDefault 8123;
        };

        ldap-clients = [{groups.${serviceName} = {};}];
      };
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    {
      services.home-assistant = {
        enable = true;
        config.http = {
          server_port = cfg.provide.ports.${portName}.port;
          use_x_forwarded_for = true;
          trusted_proxies = [
            (cfg.provide.ports.${portName}.getAddress "<ip>")
            "100.64.0.1" # TODO: remove when fixed
            "127.0.0.1"
            "::1"
          ];
        };
      };
    }

    # --- LDAP INTEGRATION
    (let
      ldapServer = cfg.require.ldap-server;
      secrets = filterAttrs (name: _: name == ldapServer.users.search.secretName) ldapServer.secrets;
    in
      mkIf (ldapServer != null) {
        sops = {inherit secrets;};
        users.groups = mkGroupsFromSecretsWithMembers secrets ["hass"];

        services.home-assistant.config.homeassistant.auth_providers = [
          {
            type = "command_line";
            meta = true; # allow outputting name and group
            # https://github.com/frenchface/hassioldap/blob/7b7b2fcb863d7d7cf98b5abd373014e6ee9119e0/ldapauth.sh
            command = lib.getExe (pkgs.writeShellApplication {
              name = "ha-ldap-login";
              runtimeInputs = with pkgs; [openldap gnugrep coreutils gawk];
              text = ''
                if [ -z "$username" ]; then exit 1; fi
                if [ -z "$password" ]; then exit 1; fi

                searchOut=$(ldapsearch \
                  -H ${ldapServer.getAddress "<protocol>://<domain>:<port>"} \
                  -b "${ldapServer.baseDN}" \
                  -D "cn=$username,ou=people,${ldapServer.baseDN}" \
                  -x -w "$password" \
                  "$(printf '(&(uid=%s)(|(%s=cn=%s,ou=groups,%s)(uid=%s)))' \
                    "$username" \
                    '${ldapServer.attributes.memberof}' '${serviceName}' '${ldapServer.baseDN}' \
                    '${ldapServer.users.admin.dn}')" \
                  )

                if [[ "$searchOut" =~ "numEntries" ]]; then
                  echo "User '$username' authenticated successfully."
                  echo "name = $(echo "$searchOut" | grep "cn: " | awk '{$1=""; print $0;}' | tail -c +2)"

                  if [ "$username" == "${ldapServer.users.admin.dn}" ]; then
                    echo "group = system-admin"
                  else
                    echo "group = system-users"
                  fi
                  exit 0
                fi

                # fallback
                exit 1
              '';
            });
          }
          {type = "homeassistant";} # fallback incase anything goes wrong, without that I am locked out
        ];
      })
  ]);
}
