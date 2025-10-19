lib: let
  inherit (lib) types mkOption mkEnableOption;
in
  serviceName: {...}: {
    options.network.services.${serviceName} = mkOption {
      description = "Configuration for the ${serviceName} service.";
      type = types.submodule (_module: {
        options = {
          enable = mkEnableOption "the ${serviceName} service";

          host = mkOption {
            type = types.str;
            description = "The host this service should run on.";
          };

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
                  type = types.submodule {
                    options = {
                      enable = mkEnableOption "reverse proxy for this port";

                      host = mkOption {
                        type = types.str;
                        description = "The reverse proxy host that will handle proxying this port.";
                        default = _module.config.host;
                      };

                      method = mkOption {
                        type = types.enum ["virtual-host" "stream"];
                        default = "virtual-host";
                        description = ''
                          The reverse proxy method to use:
                          - "virtual-host": HTTP(S) virtual host (subdomain-based routing)
                          - "stream": TCP/UDP stream forwarding (for non-HTTP protocols)
                        '';
                      };

                      subdomain = mkOption {
                        type = types.str;
                        default = "";
                        description = "The subdomain for virtual-host method. Only used when method is 'virtual-host'.";
                      };

                      extraVirtualHostsConfig = mkOption {
                        type = types.attrs;
                        default = {};
                        description = "Extra options to merge into services.nginx.virtualHosts.<name>. Only used when method is 'virtual-host'.";
                      };
                    };
                  };
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
    };
  }
