{
  config,
  lib,
  hostName,
  ...
}: let
  inherit (builtins) throw length filter head concatStringsSep foldl' replaceStrings attrNames attrValues;
  inherit (lib) pipe mkMerge;
  inherit (lib.attrsets) attrsToList filterAttrs mapAttrsToList mapAttrs mapAttrs';
  inherit (lib.lists) flatten range;

  cfg = config.network;

  networkLib = rec {
    # Flatten all enabled services across all hosts into list of:
    # {
    #   hostName: string
    #   serviceName: string
    #   serviceCfg: attrset
    # }
    allEnabledServices = pipe cfg.hosts [
      attrsToList
      (map (host:
        pipe host.value.services [
          (filterAttrs (_: service: service.enable or true))
          (mapAttrsToList (name: value: {
            serviceName = name;
            serviceCfg = value;
            hostName = host.name;
          }))
        ]))
      flatten
    ];

    # Flatten all declared ports across all hosts into a list of:
    # {
    #   hostName: string;
    #
    #   portName: string;
    #   port: int;
    #   portCfg: attrset;
    # }
    # Ports that declare ranges are flattened into individual entries.
    allPorts = pipe cfg.hosts [
      attrsToList
      (
        map (host:
          mapAttrsToList (portName: portCfg: let
            declaredPort = {
              hostName = host.name;

              inherit portName portCfg;
              inherit (portCfg) port;
            };
          in
            if portCfg.portRange == null
            then declaredPort
            else map (port: declaredPort // {inherit port;}) (range portCfg.portRange.from portCfg.portRange.to))
          host.value.ports)
      )
      flatten
    ];

    getAddress = {
      portName,
      hostName,
    }: let
      portCfg =
        if (cfg.hosts.${hostName} or null) == null
        then throw "getAddress: host ${hostName} is not defined"
        else if (cfg.hosts.${hostName}.ports.${portName} or null) == null
        then throw "getAddress: port ${portName} is not defined on host ${hostName}"
        else cfg.hosts.${hostName}.ports.${portName};

      address = {
        protocol =
          if portCfg.protocol != null
          then portCfg.protocol
          else throw "getAddress: ${hostName}: ${portName}: Protocol is null. It cannot be referenced.";
        port = portCfg.port;
        domain =
          if portCfg.reverseProxy.enable
          then portCfg.reverseProxy.domain
          else throw "getAddress: ${hostName}: ${portName}: Domain cannot be referenced because port is not reverse proxied.";
        host =
          if hostName == config.networking.hostName
          then "localhost"
          else hostName;
        ip = cfg.hosts.${hostName}.vpn.ip;
      };
    in
      replaceStrings (attrNames address) (attrValues address);

    serviceEnabledAnywhere = serviceName: (filter (e: e.serviceName == serviceName) allEnabledServices) != [];

    # Variables useful to network modules
    variables = rec {
      hostSrvs = variables.hostCfg.services;
      networkCfg = config.network;
      hostCfg = networkCfg.hosts.${hostName};
      ports = hostCfg.ports;
    };

    getServiceVariables = serviceName:
      variables
      // rec {
        inherit serviceName;
        portName = serviceName;
        cfg = variables.hostCfg.services.${serviceName};
        stateDir = "/var/lib/${serviceName}";
        integrationHelpers =
          mapAttrs (integrationName: integrationCfg: let
            scopedName = name: "integrations/${integrationName}/${integrationCfg.id}/${serviceName}/${name}";
          in {
            # Used in `mkMerge` to quickly register secrets defined in `remote` block of integrations into the current system and giving specifc users access to them
            mkRegisterIntegrationSecretsConfig = {
              secrets, # list of secrets in the form of sops.secrets.<name>.this
              users, # list of usernames
            }:
              mkMerge (mapAttrsToList (name: secret: {
                  sops.secrets.${scopedName name} = secret;
                  users.groups.${secret.group}.members = users;
                })
                secrets);
            # Used to get the integration secret file path
            getSopsFile = name: config.getSopsFile (scopedName name);
          })
          cfg.integrations;
      };
  };
in {
  config.lib.network = networkLib;
}
