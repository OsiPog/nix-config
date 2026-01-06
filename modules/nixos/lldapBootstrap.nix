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

  cfg = config.services.lldap;
  cfgBoot = cfg.bootstrap;
in {
  options.services.lldap.bootstrap = {
    enable = mkEnableOption "seeding of the lldap server using the bootstrap.sh script";
    scriptFile = mkOption {
      description = "Path to the bootstrap.sh script file.";
      type = types.pathWith {absolute = true;};
      default = "${pkgs.lldap.src}/scripts/bootstrap.sh";
    };
    cleanup = {
      enable = mkEnableOption "deletion of groups and users not specified in config files, also remove users from groups that they do not belong to";
      keepUsers = mkEnableOption "not cleaning up old users";
      keepGroupMembership = mkEnableOption "not cleaning up old group memberships";
      keepGroups = mkEnableOption "not cleaning up old groups";
    };
    users = {
      schema = mkOption {
        description = "Schema definition for users. See https://github.com/lldap/lldap/blob/main/example_configs/bootstrap/bootstrap.md#user-and-group-schema-config-file-example";
        type = with types; listOf attrs;
        default = null;
      };
      configs = mkOption {
        description = "Users to be seeded. Attribute names are the 'id' field and an additional `password_file` attribute can be passed. Everything else is the same as here: https://github.com/lldap/lldap/blob/main/example_configs/bootstrap/bootstrap.md#user-config-file-example";
        type = types.attrs;
        default = null;
      };
    };
    groups = {
      schema = mkOption {
        description = "Schema definition for groups. See https://github.com/lldap/lldap/blob/main/example_configs/bootstrap/bootstrap.md#user-and-group-schema-config-file-example";
        type = with types; listOf attrs;
        default = null;
      };
      configs = mkOption {
        description = "Groups to be seeded. Attribute names are the 'name' field. Everything else is the same as here: https://github.com/lldap/lldap/blob/main/example_configs/bootstrap/bootstrap.md#group-config-file-example";
        type = types.attrs;
        default = null;
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
        DO_CLEANUP = cfgBoot.cleanup.enable;
        DO_CLEANUP_USERS = cfgBoot.cleanup.enable && !cfgBoot.cleanup.keepUsers;
        DO_CLEANUP_GROUP_MEMBERSHIP = cfgBoot.cleanup.enable && !cfgBoot.cleanup.keepGroupMembership;
        DO_CLEANUP_GROUPS = cfgBoot.cleanup.enable && !cfgBoot.cleanup.keepGroups;
      };

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
          else "should not happen"
        }"

        export USER_SCHEMAS_DIR=user_schemas
        mkdir -p $USER_SCHEMAS_DIR
        rm -f $USER_SCHEMAS_DIR/*
        ${
          if cfgBoot.users.schema != null
          then "cp ${schemaFile cfgBoot.users.schema} $USER_SCHEMAS_DIR"
          else ""
        }

        export GROUP_SCHEMAS_DIR=group_schemas
        mkdir -p $GROUP_SCHEMAS_DIR
        rm -f $GROUP_SCHEMAS_DIR/*
        ${
          if cfgBoot.groups.schema != null
          then "cp ${schemaFile cfgBoot.groups.schema} $GROUP_SCHEMAS_DIR"
          else ""
        }

        export USER_CONFIGS_DIR=user_configs
        mkdir -p user_configs
        rm -f $USER_CONFIGS_DIR/*
        ${if cfgBoot.users.configs != null then ''
          cp ${}    
        ''}


        export GROUP_CONFIGS_DIR=group_configs
        mkdir -p $GROUP_CONFIGS_DIR
        rm -f $GROUP_CONFIGS_DIR/*
        ${
          if cfgBoot.groups.configs != null
          then "cp ${configsFile (mapAttrsToList (name: group: group // {inherit name;}) cfgBoot.groups.configs)} $GROUP_CONFIGS_DIR"
          else ""
        }

        ${lib.getExe pkgs.bash} ${cfgBoot.scriptFile}
      '';

      serviceConfig = {
        StateDirectory = "lldap";
        StateDirectoryMode = "0750";
        WorkingDirectory = "%S/bootstrap";
        UMask = "0027";
        User = "lldap";
        Group = "lldap";
      };
    };
  };
}
