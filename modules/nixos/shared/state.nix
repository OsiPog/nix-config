{
  lib,
  config,
  flake,
  ...
}:
let
  inherit (builtins) attrNames readDir;
  inherit (lib) mkOption types;

  cfg = config.state;
in
{
  options.state = {
    host = {
      ssh = {
        public-key = mkOption {
          type = types.str;
          description = "SSH public key for the host";
        };

        allow-connections-from = mkOption {
          type = with types; listOf (enum (attrNames (readDir ../../../hosts)));
          default = [ ];
          description = "List of hosts allowed to connect via SSH";
        };
      };
    };
  };
  config = {
    services.openssh.enable = (cfg.host.ssh.allow-connections-from) != [ ];

    users.users.root.openssh.authorizedKeys.keys = map (
      other: flake.nixosConfigurations.${other}.config.state.host.ssh.public-key
    ) cfg.host.ssh.allow-connections-from;
  };
}
