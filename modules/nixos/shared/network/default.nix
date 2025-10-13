{
  lib,
  config,
  hostName,
  ...
}: let
  inherit (builtins) attrNames readDir filter listToAttrs;
  inherit (lib) pipe types mkOption mkEnableOption;
  inherit (lib.attrsets) attrsToList;

  hostnames = attrNames (readDir ../../../../hosts);
  # Define the available hostnames as an enum based on /hosts folder names
  hostnameEnum = types.enum hostnames;

  cfg = config.network;
  hostCfg = cfg.hosts.${hostName};

  toACMECert = serviceName: "${cfg.services.${serviceName}.reverseProxy.subdomain}-cert";
  toFullDomain = serviceName: "${cfg.services.${serviceName}.reverseProxy.subdomain}.${cfg.hosts.${cfg.services.${serviceName}.reverseProxy.host}.reverseProxy.domain}";
in {
  options.network = {
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
      ./reverseProxy
    ]
    ++ (map (e: ./services + "/${e}") (attrNames (readDir ./services)));

  config = {
    lib.network = {
      inherit toACMECert toFullDomain;
    };

    assertions =
      []
      # Check the services which should be reverse proxied if the reverse proxy host is actually a reverse proxy.
      ++ (pipe cfg.services [
        attrsToList
        (filter (service: service.value.reverseProxy.enable))
        (map (service: {
          assertion = cfg.hosts.${service.value.reverseProxy.host}.reverseProxy.enable;
          message = "Reverse proxy host \"${service.value.reverseProxy.host}\" of service \"${service.name}\" is not a reverse proxy.";
        }))
      ]);

    # Define the options for each host
    network.hosts = listToAttrs (map (name: {
        inherit name;
        value = {};
      })
      hostnames);

    # Add authorized keys from hosts that are allowed to connect
    users.users.leaf.openssh.authorizedKeys.keys = map (
      other: cfg.hosts.${other}.ssh.publicKey
    ) (hostCfg.ssh.allowConnectionsFrom);
  };
}
