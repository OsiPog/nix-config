{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (builtins) toFile toJSON;
  inherit (lib) mkEnableOption mkIf mkOption types;
  inherit (lib.strings) concatLines;
  inherit (lib.attrsets) mapAttrsToList;

  # just a json file
  schemaFile = attrs: toFile "file.json" (toJSON attrs);
  # json objects seperated by newlines in a json file
  configsFile = list: toFile "file.json" (concatLines (map toJSON list));

  toListWithAttrName = attrname: list: mapAttrsToList (name: value: value // {${attrname} = name;}) list;

  cfg = config.services.lldap;
  cfgBoot = cfg.bootstrap;
in {
  options.services.lldap.bootstrap = {
    enable = mkEnableOption "seeding of the lldap server using the bootstrap.sh script";
    cleanup = {
      enable = mkEnableOption "deletion of groups and users not specified in config files, also remove users from groups that they do not belong to";
      keepUsers = mkEnableOption "not cleaning up old users";
      keepGroupMembership = mkEnableOption "not cleaning up old group memberships";
      keepGroups = mkEnableOption "not cleaning up old groups";
    };
    users = {
      schema = mkOption {
        description = "Schema definition for users. Attribute names are the 'name' field. See https://github.com/lldap/lldap/blob/main/example_configs/bootstrap/bootstrap.md#user-and-group-schema-config-file-example";
        type = types.attrs;
        default = {};
      };
      configs = mkOption {
        description = "Users to be seeded. Attribute names are the 'id' field. Everything else is the same as here: https://github.com/lldap/lldap/blob/main/example_configs/bootstrap/bootstrap.md#user-config-file-example but note that the 'password_file' attribute can be used which is currently not documented.";
        type = types.attrs;
        default = {};
        example = {
          username = {
            firstName = "First";
            lastName = "Last";
            password = "changeme";
            avatar_file = "/path/to/avatar.jpg";
            avatar_url = "https://i.imgur.com/nbCxk3z.jpg";
            displayName = "Display Name";
            email = "username@example.com";
            gravatar_avatar = "false";
            groups = [
              "group-1"
              "group-2"
            ];
            weserv_avatar = "false";
          };
          other_user = {
            firstName = "First";
            lastName = "Name";
            displayName = "Other User";
            password_file = "/run/secrets/ldap/user_pass";
          };
        };
      };
    };
    groups = {
      schema = mkOption {
        description = "Schema definition for groups. Attribute names are the 'name' field. See https://github.com/lldap/lldap/blob/main/example_configs/bootstrap/bootstrap.md#user-and-group-schema-config-file-example";
        type = types.attrs;
        default = {};
      };
      configs = mkOption {
        description = "Groups to be seeded. Attribute names are the 'name' field. Everything else is the same as here: https://github.com/lldap/lldap/blob/main/example_configs/bootstrap/bootstrap.md#group-config-file-example";
        type = types.attrs;
        default = {};
        example = {
          tech = {};
          admin = {};
          hr = {};
        };
      };
    };
  };
  config = mkIf (cfg.enable && cfgBoot.enable) {
    systemd.services.lldap-bootstrap = {
      description = "Bootstrap Script for LLDAP";
      after = ["lldap.service"];
      wantedBy = ["multi-user.target"];

      environment = {
        LLDAP_URL = "http://localhost:${toString cfg.settings.http_port}";
        LLDAP_ADMIN_USERNAME = cfg.settings.ldap_user_dn;
        LLDAP_SET_PASSWORD_PATH = "${cfg.package}/bin/lldap_set_password";
        DO_CLEANUP = toString (cfgBoot.cleanup.enable);
        DO_CLEANUP_USERS = toString (cfgBoot.cleanup.enable && !cfgBoot.cleanup.keepUsers);
        DO_CLEANUP_GROUP_MEMBERSHIP = toString (cfgBoot.cleanup.enable && !cfgBoot.cleanup.keepGroupMembership);
        DO_CLEANUP_GROUPS = toString (cfgBoot.cleanup.enable && !cfgBoot.cleanup.keepGroups);
      };

      path = with pkgs; [
        jq
        jo
        curl
        bash
      ];

      script = ''
        export LLDAP_ADMIN_PASSWORD="${
          if (cfg.settings.ldap_user_pass_file or null) != null
          then "$(cat ${cfg.settings.ldap_user_pass_file})"
          else if (cfg.environment.LLDAP_LDAP_USER_PASS_FILE)
          then "$(cat ${cfg.environment.LLdap})"
          else if (cfg.settings.ldap_user_pass or null) != null
          then cfg.settings.ldap_user_pass
          else if (cfg.environment.LLDAP_LDAP_USER_PASS or null) != null
          then cfg.environment.LLDAP_LDAP_USER_PASS
          else throw "Admin password for LLDAP could not be determined."
        }"

        ${
          if cfgBoot.users.schema != {}
          then
            # sh
            ''
              export USER_SCHEMAS_DIR=user_schemas
              mkdir -p $USER_SCHEMAS_DIR
              rm -f $USER_SCHEMAS_DIR/*
              cp ${schemaFile (toListWithAttrName "name" cfgBoot.users.schema)} $USER_SCHEMAS_DIR
            ''
          else ""
        }

        ${
          if cfgBoot.groups.schema != {}
          then
            # sh
            ''
              export GROUP_SCHEMAS_DIR=group_schemas
              mkdir -p $GROUP_SCHEMAS_DIR
              rm -f $GROUP_SCHEMAS_DIR/*
              cp ${schemaFile (toListWithAttrName "name" cfgBoot.groups.schema)} $GROUP_SCHEMAS_DIR''
          else ""
        }

        ${
          if cfgBoot.users.configs != {}
          then
            # sh
            ''
              export USER_CONFIGS_DIR=user_configs
              mkdir -p user_configs
              rm -f $USER_CONFIGS_DIR/*
              cp ${configsFile (toListWithAttrName "id" cfgBoot.users.configs)} $USER_CONFIGS_DIR
            ''
          else ""
        }

        ${
          if cfgBoot.groups.configs != {}
          then
            # sh
            ''
              export GROUP_CONFIGS_DIR=group_configs
              mkdir -p $GROUP_CONFIGS_DIR
              rm -f $GROUP_CONFIGS_DIR/*
              cp ${configsFile (toListWithAttrName "name" cfgBoot.groups.configs)} $GROUP_CONFIGS_DIR
            ''
          else ""
        }

        bash ${cfg.package.src}/scripts/bootstrap.sh
      '';

      serviceConfig = {
        StateDirectory = "lldap";
        StateDirectoryMode = "0750";
        WorkingDirectory = "%S/lldap";
        UMask = "0027";
        User = "lldap";
        Group = "lldap";
      };
    };
  };
}
