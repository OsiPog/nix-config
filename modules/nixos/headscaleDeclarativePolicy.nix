{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkOption types mkIf filterAttrs;
  inherit (builtins) toJSON;

  aclEntryType = types.submodule {
    options = {
      action = mkOption {
        type = types.enum ["accept" "deny"];
      };
      src = mkOption {
        type = types.listOf types.str;
      };
      dst = mkOption {
        type = types.listOf types.str;
      };
      proto = mkOption {
        type = types.nullOr (types.enum ["tcp" "udp" "icmp"]);
        default = null;
      };
    };
  };

  policyType = types.submodule {
    options = {
      groups = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = {};
        description = "Collections of users. A user can be in multiple groups; groups cannot contain groups.";
      };
      tagOwners = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = {};
        description = "Association between a tag and the users/groups allowed to set it on a node.";
      };
      hosts = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Host aliases defined as IP/mask. Use /32 for single hosts.";
      };
      acls = mkOption {
        type = types.listOf aclEntryType;
        default = [];
        description = "Ordered list of ACL rules evaluated top-to-bottom.";
      };
    };
  };

  policy = config.services.headscale.policy;

  policyAttrs = p: {
    inherit (p) groups tagOwners hosts;
    acls = map (entry: filterAttrs (_: v: v != null) entry) p.acls;
  };
in {
  options.services.headscale.policy = mkOption {
    type = types.nullOr policyType;
    default = null;
    description = "Headscale ACL policy. When set, writes a JSON policy file and wires it into services.headscale.settings.policy.path.";
  };

  config = mkIf (policy != null) {
    services.headscale.settings.policy.path = pkgs.writeTextFile {
      name = "headscale-policy.json";
      text = toJSON (policyAttrs policy);
    };
  };
}
