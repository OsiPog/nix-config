flake: serviceName: {
  settingsOptions ? {},
  defaults ? {},
}: {
  lib,
  config,
  ...
}: let
  inherit (builtins) foldl' concatLists isAttrs;
  inherit (lib) types mkOption mkEnableOption pipe mkDefault;
  inherit (lib.attrsets) recursiveUpdate attrsToList mapAttrs;

  hostNames = flake.lib.nixosHostNames;

  serviceOptions = hostName: let
    cfg = config.network.hosts.${hostName}.services.${serviceName};
  in {
    options.network.hosts.${hostName}.services.${serviceName} = mkOption {
      description = "Configuration for the ${serviceName} service.";
      type = types.submodule (_module: {
        options = {
          enable = mkEnableOption "the ${serviceName} service";
          settings = settingsOptions;
          ports = mkOption {
            type = types.attrsOf (types.submodule (_portModule: {
              options = {
                port = mkOption {
                  type = types.nullOr types.port;
                  default = null;
                  description = "Single port number for this service endpoint.";
                };

                portRange = mkOption {
                  type = types.nullOr (types.submodule {
                    options = {
                      from = mkOption {
                        type = types.port;
                        description = "Start of the port range (inclusive).";
                      };
                      to = mkOption {
                        type = types.port;
                        description = "End of the port range (inclusive).";
                      };
                    };
                  });
                  default = null;
                  description = "Port range for this service endpoint.";
                };

                reverseProxy = mkOption {
                  type = types.submodule (_proxyModule: {
                    options = {
                      enable = mkEnableOption "reverse proxy for this port";

                      host = mkOption {
                        type = types.str;
                        description = "The reverse proxy host that will handle proxying this port.";
                        default = hostName;
                      };

                      method = mkOption {
                        type = types.enum ["virtual-host" "stream"];
                        default =
                          if (_proxyModule.config.subdomain == null)
                          then "stream"
                          else "virtual-host";
                        description = ''
                          The reverse proxy method to use:
                          - "virtual-host": HTTP(S) virtual host (subdomain-based routing)
                          - "stream": TCP/UDP stream forwarding (for non-HTTP protocols)
                        '';
                      };

                      subdomain = mkOption {
                        type = with types; nullOr str;
                        default = null;
                        description = "If set the service will be reverse proxied through HTTPS a virtual host on the reverse proxy.";
                      };

                      extraVirtualHostsConfig = mkOption {
                        type = types.attrs;
                        default = {};
                        description = "Extra options to merge into services.nginx.virtualHosts.<name>. Only used when method is 'virtual-host'.";
                      };

                      udp = mkEnableOption "UDP stream instead of TCP. Only relevant when method is 'stream'";
                    };
                  });
                  default = {};
                  description = "Reverse proxy configuration for this port.";
                };
              };
            }));
            default = {};
            description = ''
              Named ports for this service. Each port can have either a single port number
              or a port range, along with optional reverse proxy configuration.
            '';
          };
        };
      });
      default = {};
    };
    config = {
      assertions = pipe cfg.ports [
        attrsToList
        (map (
          p: [
            # Each port must have either single port or port range configured
            {
              assertion = (p.value.port == null) != (p.value.portRange == null);
              message = "Service \"${serviceName}\" port \"${p.name}\" must have exactly one of 'port' or 'portRange' defined (not both, not neither).";
            }
            # In port range from should be less than or equal to to
            {
              assertion = p.value.portRange == null || (p.value.portRange.from <= p.value.portRange.to);
              message = "Service \"${serviceName}\" port \"${p.name}\" has invalid port range: 'from' (${toString p.value.portRange.from}) must be <= 'to' (${toString p.value.portRange.to}).";
            }
            # Check that virtual-host reverse proxy has a subdomain
            {
              assertion = !p.value.reverseProxy.enable || p.value.reverseProxy.method != "virtual-host" || p.value.reverseProxy.subdomain != null;
              message = "Service \"${serviceName}\" port \"${p.name}\" uses virtual-host reverse proxy but no subdomain is specified.";
            }
            # Check that port ranges don't use virtual-host method
            {
              assertion = p.value.portRange == null || !p.value.reverseProxy.enable || p.value.reverseProxy.method != "virtual-host";
              message = "Service \"${serviceName}\" port \"${p.name}\" has a port range and cannot use 'virtual-host' reverse proxy method. Use 'stream' instead.";
            }
            # Check that reverse proxy host is actually a reverse proxy
            {
              assertion = !p.value.reverseProxy.enable || config.network.hosts.${p.value.reverseProxy.host}.reverseProxy.enable;
              message = "Reverse proxy host \"${p.value.reverseProxy.host}\" of service \"${serviceName}\" port \"${p.name}\" is not a reverse proxy.";
            }
          ]
        ))
        concatLists
      ];

      # Set defaults
      network.hosts.${hostName}.services.${serviceName} = let
        # Recursively apply mkDefault to all values in an attribute set
        applyDefaultsRecursively = attrs:
          mapAttrs (name: value:
            if isAttrs value && !value._type or false
            then applyDefaultsRecursively value
            else mkDefault value)
          attrs;
      in
        applyDefaultsRecursively defaults;
    };
  };
in
  pipe hostNames [
    # create a service config for each host
    (map serviceOptions)
    # merge them together
    (foldl' recursiveUpdate {})
  ]
