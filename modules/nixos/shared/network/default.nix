{
  lib,
  config,
  hostName,
  ...
}: let
  inherit (lib) types mkOption mkEnableOption mkIf;

  networkCfg = config.network;
  hostCfg = networkCfg.hosts.${hostName};
in {
  options.network = {
    enable = (mkEnableOption "network module") // {default = true;};

    sharedModules = mkOption {
      type = with types; listOf raw;
      default = [];
      description = "Extra modules added to all hosts.";
    };

    hosts = mkOption {
      type = with types;
        attrsOf (submoduleWith {
          class = "networkHost";
          specialArgs.osConfig = config;

          modules = [
            (
              {name, ...}: {
                imports = networkCfg.sharedModules;

                options = {
                  vpn.ip = mkOption {
                    type = types.str;
                    description = "VPN IP address for the host";
                  };
                  ssh = {
                    publicKey = mkOption {
                      type = types.str;
                      description = "SSH public key for the host";
                    };
                    allowConnectionsFrom = mkOption {
                      type = with types; listOf (enum nixosHostNames);
                      default = [];
                      description = "List of host names that are allowed to connect to this host via SSH";
                    };
                  };
                  domain = mkOption {
                    type = with types; nullOr str;
                    default = null;
                    description = "A domain with its DNS configured to resolve to the IP address of this host on *.domain.tld.";
                  };

                  ports = mkOption {
                    description = "Ports opened on this host";
                    type = types.attrsOf (types.submodule (_portModule: {
                      options = {
                        port = mkOption {
                          type = types.nullOr types.port;
                          default = null;
                          description = "Single port number";
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
                                  if (_proxyModule.config.subdomain == null)
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
                };
              }
            )
          ];
        });
      default = {};
      description = "Per host network config";
    };
  };

  imports = [
    ./lib
    ./importHosts.nix

    ./services/headscale
    ./services/reverseProxy.nix
  ];

  config = mkIf networkCfg.enable {
    # Add authorized keys from hosts that are allowed to connect
    users.users.leaf.openssh.authorizedKeys.keys = map (
      other: networkCfg.hosts.${other}.ssh.publicKey
    ) (hostCfg.ssh.allowConnectionsFrom);
  };
}
