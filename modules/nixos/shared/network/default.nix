{
  lib,
  config,
  hostName,
  ...
}: let
  inherit (builtins) attrNames readDir filter listToAttrs;
  inherit (lib) pipe types mkOption mkEnableOption mkIf mkMerge;
  inherit (lib.attrsets) attrsToList;

  hostnames = attrNames (readDir ../../../../hosts);
  # Define the available hostnames as an enum based on /hosts folder names
  hostnameEnum = types.enum hostnames;

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
      assertions = let
        allPorts = pipe cfg.services [
          attrsToList
          (map (service:
            map (portEntry:
              let
                portCfg = portEntry.value;
              in {
                serviceName = service.name;
                portName = portEntry.name;
                portConfig = portCfg;
              }
            ) (attrsToList service.value.ports)
          ))
          (lib.lists.flatten)
        ];
      in
        []
        # Check that each port has exactly one of port or portRange
        ++ (map (p: {
          assertion = (p.portConfig.port == null) != (p.portConfig.portRange == null);
          message = "Service \"${p.serviceName}\" port \"${p.portName}\" must have exactly one of 'port' or 'portRange' defined (not both, not neither).";
        }) allPorts)
        # Check that port ranges are valid
        ++ (pipe allPorts [
          (filter (p: p.portConfig.portRange != null))
          (map (p: {
            assertion = p.portConfig.portRange.from <= p.portConfig.portRange.to;
            message = "Service \"${p.serviceName}\" port \"${p.portName}\" has invalid port range: 'from' (${toString p.portConfig.portRange.from}) must be <= 'to' (${toString p.portConfig.portRange.to}).";
          }))
        ])
        # Check that virtual-host reverse proxy has a subdomain
        ++ (pipe allPorts [
          (filter (p: p.portConfig.reverseProxy.enable && p.portConfig.reverseProxy.method == "virtual-host"))
          (map (p: {
            assertion = p.portConfig.reverseProxy.subdomain != "";
            message = "Service \"${p.serviceName}\" port \"${p.portName}\" uses virtual-host reverse proxy but no subdomain is specified.";
          }))
        ])
        # Check that port ranges don't use virtual-host method
        ++ (pipe allPorts [
          (filter (p: p.portConfig.portRange != null && p.portConfig.reverseProxy.enable))
          (map (p: {
            assertion = p.portConfig.reverseProxy.method != "virtual-host";
            message = "Service \"${p.serviceName}\" port \"${p.portName}\" has a port range and cannot use 'virtual-host' reverse proxy method. Use 'stream' instead.";
          }))
        ])
        # Check the ports which should be reverse proxied if the reverse proxy host is actually a reverse proxy.
        ++ (pipe allPorts [
          (filter (p: p.portConfig.reverseProxy.enable))
          (map (p: {
            assertion = cfg.hosts.${p.portConfig.reverseProxy.host}.reverseProxy.enable;
            message = "Reverse proxy host \"${p.portConfig.reverseProxy.host}\" of service \"${p.serviceName}\" port \"${p.portName}\" is not a reverse proxy.";
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
