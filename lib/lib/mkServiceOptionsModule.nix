lib: let
  inherit (lib) types mkOption mkEnableOption;
in
  serviceName: {...}: {
    options.network.services.${serviceName} = mkOption {
      description = "Function that should be used to create new services.";
      type =
        types.submodule
        (_module: {
          options = {
            enable = mkEnableOption "the service";
            port = mkOption {
              type = types.port;
              description = "Port number for the service";
            };
            host = mkOption {
              type = types.nullOr types.str;
              description = "The host this service should run on.";
            };
            reverseProxy = {
              enable = mkEnableOption "this service should be reverse proxied from a server.";
              method = mkOption {
                description = "The method used to proxy this service.";
                type = with types; enum ["virtual-host" "stream"];
                default = "virtual-host";
              };
              subdomain = mkOption {
                type = types.str;
                description = "The subdomain name this service should be reached on.";
                default = "";
              };
              host = mkOption {
                type = types.str;
                description = "A reverse proxy enabled host.";
                default = _module.config.host;
              };
              extraVirtualHostsConfig = mkOption {
                type = types.attrs;
                description = "Extra options added to services.nginx.virtualHosts.<name>";
                default = {};
              };
            };
          };
        });
    };
  }
