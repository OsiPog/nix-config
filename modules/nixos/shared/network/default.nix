_module @ {
  lib,
  flake,
  config,
  hostName,
  ...
}: let
  inherit (builtins) attrNames readDir pathExists;
  inherit (lib) types mkOption mkEnableOption mkIf mkOptionDefault;
  inherit (lib.attrsets) genAttrs;

  hostnames = flake.lib.nixosHostNames;
  # Define the available hostnames as an enum based on /hosts folder names
  hostnameEnum = types.enum hostnames;

  cfg = config.network;
  hostCfg = cfg.hosts.${hostName};
in {
  options.network = {
    enable = (mkEnableOption "network module") // {default = true;};

    hosts = genAttrs hostnames (hostname: {
      ssh = {
        publicKey = mkOption {
          type = types.str;
          description = "SSH public key for the host";
        };
        allowConnectionsFrom = mkOption {
          type = types.listOf hostnameEnum;
          default = [];
          description = "List of host names that are allowed to connect to this host via SSH";
        };
      };
      # Is populated by `mkServiceOptionsModule`
      services = {};
    });
  };

  imports =
    [
      ./lib
      ./importHosts.nix
    ]
    ++ (map (e: ./services + "/${e}") (attrNames (readDir ./services)));

  config = mkIf cfg.enable {
    # Add authorized keys from hosts that are allowed to connect
    users.users.leaf.openssh.authorizedKeys.keys = map (
      other: cfg.hosts.${other}.ssh.publicKey
    ) (hostCfg.ssh.allowConnectionsFrom);
  };
}
