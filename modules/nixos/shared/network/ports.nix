{
  lib,
  config,
  ...
}: let
  inherit (lib) mkOption mkEnableOption types pipe;
  inherit (lib.lists) flatten;
  inherit (lib.attrsets) mapAttrsToList filterAttrs attrsToList;
  inherit (lib.strings) hasSuffix splitString length;
in {
  network.sharedModules = [
    ({
      name,
      config,
      ...
    }: {
      options.ports = mkOption {
        description = "Ports opened on this host";
        type = types.attrsOf (types.submodule (_portModule: {
          options = {
            port = mkOption {
              type = types.nullOr types.port;
              default = null;
              description = "Single port number";
            };

            protocol = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "The protocol used on this port.";
            };

            host = mkOption {
              type = types.str;
              default = name;
              readOnly = true;
              description = "The host name of the host the port belongs to.";
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
              description = "Port range for this port";
            };

            reverseProxy = mkOption {
              type = types.submodule (_proxyModule: {
                options = {
                  enable = mkEnableOption "reverse proxy for this port";
                  hidden = mkEnableOption "that the service is only accessable in the VPN";

                  method = mkOption {
                    type = types.enum ["virtual-host" "stream"];
                    default =
                      if (_proxyModule.config.domain == null)
                      then "stream"
                      else "virtual-host";
                    description = ''
                      The reverse proxy method to use:
                      - "virtual-host": HTTP(S) virtual host (subdomain-based routing)
                      - "stream": TCP/UDP stream forwarding (for non-HTTP protocols)
                    '';
                  };

                  domain = mkOption {
                    type = with types; nullOr str;
                    default = null;
                    description = "If set the service will be reverse proxied through HTTPS a virtual host on the reverse proxy.";
                  };

                  extraConfig = mkOption {
                    type = with types; either attrs str;
                    default = {};
                    description = ''
                      Extra configuration options:
                      - When method is 'virtual-host': merged into services.nginx.virtualHosts.<name>
                      - When method is 'stream': applied as additional configuration in the stream server block
                    '';
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
      };
    })
  ];

  assertions = pipe config.network.hosts [
    attrsToList
    (
      map (
        host:
          mapAttrsToList (
            portName: portCfg: [
              {
                assertion = (portCfg.port == null) != (portCfg.portRange == null);
                message = "Port \"${portName}\" on \"${host.name}\" must have exactly one of 'port' or 'portRange' defined (not both, not neither).";
              }
              # In port range from should be less than or equal to to
              {
                assertion = portCfg.portRange == null || (portCfg.portRange.from <= portCfg.portRange.to);
                message = "Port \"${portName}\" on \"${host.name}\" has invalid port range: 'from' (${toString portCfg.portRange.from}) must be <= 'to' (${toString portCfg.portRange.to}).";
              }
              # Check that virtual-host reverse proxy has a subdomain
              {
                assertion = !portCfg.reverseProxy.enable || portCfg.reverseProxy.method != "virtual-host" || portCfg.reverseProxy.domain != null;
                message = "Port \"${portName}\" on \"${host.name}\" uses virtual-host reverse proxy but no domain is specified.";
              }
              # Check that port ranges don't use virtual-host method
              {
                assertion = portCfg.portRange == null || !portCfg.reverseProxy.enable || portCfg.reverseProxy.method != "virtual-host";
                message = "Port \"${portName}\" on \"${host.name}\" has a port range and cannot use 'virtual-host' reverse proxy method. Use 'stream' instead.";
              }
              # Check that reverse proxy host is actually a reverse proxy
              {
                assertion = !portCfg.reverseProxy.enable || (filterAttrs (_: host: hasSuffix host.domain portCfg.reverseProxy.domain)) != {};
                message = "No domain of any host is suffix of the reverse proxy domain \"${portCfg.reverseProxy.domain}\" of port \"${portName}\" on \"${host.name}\".";
              }
              {
                assertion = !portCfg.reverseProxy.enable || !portCfg.reverseProxy.hidden || portCfg.reverseProxy.method != "stream" || portCfg.reverseProxy.domain != null || (length (splitString "." portCfg.reverseProxy.domain)) >= 3;
                message = "When hiding a stream port behind the VPN you must define a subdomain";
              }
            ]
          )
          host.value.ports
      )
    )
    flatten
  ];
}
