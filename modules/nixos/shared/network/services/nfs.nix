{
  config,
  lib,
  flake,
  ...
}: let
  inherit (builtins) attrNames elem length concatStringsSep head;

  inherit (lib) mkIf mkOption mkMerge pipe types;
  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getServiceVariables;

  inherit (lib.attrsets) mapAttrs' mapAttrsToList filterAttrs;
  inherit (lib.strings) concatLines;

  inherit
    (getServiceVariables "nfs")
    serviceName
    networkCfg
    cfg
    ports
    ;
  getClientHosts = id:
    pipe networkCfg.hosts [
      (filterAttrs (_: host: host.services.${serviceName}.enable && (elem id (attrNames host.services.${serviceName}.mount))))
      attrNames
    ];

  getServerHost = id:
    pipe networkCfg.hosts [
      (filterAttrs (_: host: host.services.${serviceName}.enable && (elem id (attrNames host.services.${serviceName}.serve))))
      attrNames
      (hostName:
        if length hostName > 1
        then throw "nfs: served directory id ${id} is defined multiple times. (${concatStringsSep ", " hostName})"
        else if length hostName == 0
        then throw "nfs: served directory with id '${id}' is not defined on any nfs server."
        else head hostName)
    ];

  getServerPath = id: networkCfg.hosts.${getServerHost id}.services.${serviceName}.serve.${id};
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      optionsService = let
        attrsOfPath = with lib.types; attrsOf (pathWith {absolute = true;});
      in {
        serve = mkOption {
          description = "Serve directories using NFS. Attrnames are identifiers.";
          type = attrsOfPath;
          default = {};
        };
        mount = mkOption {
          description = "Mount served directories using NFS. Attrnames are identifiers.";
          type = attrsOfPath;
          default = {};
        };
      };
      configEnable.ports = {
        nfs-lockd.port = 4001;
        nfs-mountd.port = 4002;
        nfs-statd.port = 4000;
      };
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (mkMerge [
    # --- all
    {
      services.nfs.idmapd.settings.General.Domain = "nfsv4.localdomain";
    }

    # --- server
    (mkIf (cfg.serve != {}) {
      # user for writing in the name of nfs clients
      users = {
        users.nfs = {
          isSystemUser = true;
          uid = 1337;
          group = "nfs";
        };
        groups.nfs.gid = 137;
      };

      # bind each path into the /export directory
      fileSystems =
        mapAttrs' (id: path: {
          name = "/export/${id}";
          value = {
            device = path;
            options = ["bind"];
          };
        })
        cfg.serve;

      # server config
      services.nfs.server = {
        enable = true;
        lockdPort = ports.nfs-lockd.port;
        mountdPort = ports.nfs-mountd.port;
        statdPort = ports.nfs-statd.port;
        exports = pipe cfg.serve [
          (mapAttrsToList (
            id: path:
              "/export/${id} "
              + (pipe (getClientHosts id) [
                (map (hostName: "${hostName}(rw)"))
                (concatStringsSep " ")
              ])
          ))
          concatLines
        ];
      };
    })

    # --- client
    (mkIf (cfg.mount != {}) {
      boot.supportedFilesystems = ["nfs"];

      fileSystems =
        mapAttrs' (id: path: {
          name = path;
          value = {
            fsType = "nfs";
            device = "${getServerHost id}:/export/${id}";
            options = [
              "nfsvers=4.2"
              "x-systemd.automount"
              "noauto"
              "x-systemd.idle-timeout=600"
            ];
          };
        })
        cfg.mount;
    })
  ]);
}
