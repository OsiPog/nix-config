{
  lib,
  config,
  hostName,
  flake,
  inputs,
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
          specialArgs = {
            inherit inputs;
            inherit (config.lib.network) servicesById;
            nixosConfig = config;
          };

          modules = [
            ({...}: {
              imports = networkCfg.sharedModules;

              options = {
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
                  description = "The main domain will be set as config.networking.domain, also this servers IP-address reverse DNS points to it. A domain with its DNS configured to resolve to the IP address of this host on *.domain.tld.";
                };
                extraDomains = mkOption {
                  description = "Any other domains that resolve to this hosts ip address.";
                  default = [];
                  type = with types; listOf str;
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
    ./vpn

    ./services/authelia
    ./services/backup.nix
    ./services/dnsmasq.nix
    ./services/headscale
    # ./services/hytale-server.nix
    ./services/jellyfin
    ./services/lldap
    ./services/mailserver
    # ./services/minecraft-server.nix
    # ./services/nfs.nix
    ./services/opencloud
    # ./services/portunus
    ./services/home-assistant.nix
    ./services/reverseProxy.nix
    ./services/staticWebsites.nix
    ./services/vikunja
    ./services/actual
  ];

  config = mkIf networkCfg.enable {
    # Add authorized keys from hosts that are allowed to connect
    users.users.leaf.openssh.authorizedKeys.keys = map (
      other: networkCfg.hosts.${other}.ssh.publicKey
    ) (hostCfg.ssh.allowConnectionsFrom);

    networking.domain = hostCfg.domain;
  };
}
