{
  lib,
  config,
  hostName,
  ...
}: let
  inherit (builtins) attrNames readDir listToAttrs;
  inherit (lib) types mkOption mkEnableOption mkIf pipe;

  hostnames = attrNames (readDir ../../../../hosts);
  # Define the available hostnames as an enum based on /hosts folder names
  hostnameEnum = types.enum hostnames;
  hostnameAttrsEmpty = listToAttrs (map (name: {
      inherit name;
      value = {};
    })
    hostnames);

  cfg = config.network;
  hostCfg = cfg.hosts.${hostName};
in {
  options.network = {
    enable = mkEnableOption "network module";

    hosts = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          reverseProxy = {
            enable = mkEnableOption "a reverse proxy responsible for mapping the domains of the services to their servers";
            domain = mkOption {
              type = types.str;
              description = "The domain configured to connect to this host.";
              default = "";
            };
          };
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
        };
      });
      default = {};
      description = "Configuration for all hosts in the network";
    };

    services = {};
  };

  imports =
    [
      ./lib
      ./reverseProxy
    ]
    ++ (map (e: ./services + "/${e}") (attrNames (readDir ./services)));

  config = mkIf cfg.enable {
    # network = {
    #   # Define the options for each host
    #   hosts = hostnameAttrsEmpty;
    #   services = hostnameAttrsEmpty;
    # };

    # Add authorized keys from hosts that are allowed to connect
    users.users.leaf.openssh.authorizedKeys.keys = map (
      other: cfg.hosts.${other}.ssh.publicKey
    ) (hostCfg.ssh.allowConnectionsFrom);
  };
}
