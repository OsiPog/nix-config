{
  lib,
  config,
  hostName,
  flake,
  ...
}: let
  inherit (lib) types mkOption mkEnableOption mkIf;
  inherit (flake.lib) nixosHostNames;

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
          specialArgs.nixosConfig = config;

          modules = [
            ({...}: {
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

                stateDirs = mkOption {
                  type = with types; listOf (pathWith {absolute = true;});
                  default = [];
                  description = "A list of directories where any kind of state is stored. Useful for the backup service to know what to backup.";
                };
              };
            })
          ];
        });
      default = {};
      description = "Per host network config";
    };
  };

  imports = [
    ./lib
    ./importHosts.nix

    ./ports.nix

    ./services/authelia
    ./services/backup.nix
    ./services/dnsmasq.nix
    ./services/headscale
    ./services/hytale-server.nix
    ./services/lldap
    ./services/mailserver
    ./services/minecraft-server.nix
    ./services/portunus
    ./services/reverseProxy.nix
    ./services/staticWebsites.nix

    ./integrations/ldap
    ./integrations/mail
    ./integrations/oidc
    ./integrations/hiddenServicesWithHeadscaleAndDnsmasq.nix
  ];

  config = mkIf networkCfg.enable {
    # Add authorized keys from hosts that are allowed to connect
    users.users.leaf.openssh.authorizedKeys.keys = map (
      other: networkCfg.hosts.${other}.ssh.publicKey
    ) (hostCfg.ssh.allowConnectionsFrom);

    networking.domain = hostCfg.domain;
  };
}
