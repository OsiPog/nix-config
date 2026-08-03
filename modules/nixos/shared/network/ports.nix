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
      nixosConfig,
      ...
    }: let
      hostName = name;
    in {
      options.ports = mkOption {
        description = "Ports opened on this host";
        type = types.attrsOf (types.submodule ({name, ...} @ _portModule: let
          portName = name;
        in {
          options = {};
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
