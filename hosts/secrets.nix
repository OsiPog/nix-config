{
  pkgs,
  config,
  lib,
  inputs,
  self,
  ...
}: let
  inherit (builtins) listToAttrs;
  inherit (lib) pipe attrsToList mkOption flatten;

  hmSecretName = userName: name: "hm-secrets/${userName}/${name}";
in {
  # Import the nixos module
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  options.getSopsFile = lib.mkOption {
    description = "A helper function to get the path to a sops secret.";
  };
  config = {
    getSopsFile =
      name: config.sops.secrets.${name}.path
      /*
      or (toFile name "")
      */
      ;

    environment.systemPackages = with pkgs; [
      sops
    ];

    # Setup the secrets file
    sops.defaultSopsFormat = "yaml";

    # Generate the age key from a provided ssh key
    sops.age = {
      # The path to the age key
      # this must be '/root/.config/sops/age/keys.txt' as this is the path where sops will for an age key when using
      # `sudo sops ...`
      keyFile = "/root/.config/sops/age/keys.txt";

      # For some reason this option will not generate the age key from the given ssh key but just generate one at random
      # so we need to disable that and do it on our own down below
      generateKey = false;
    };
    # An acivation script that runs on `nixos-rebuild switch` and reboot that generates private AGE keys from all private
    # SSH keys found in /etc/ssh
    system.activationScripts = lib.mkIf (config.sops.secrets != {}) {
      generateAgeKeysFromSSH.text = lib.getExe self.packages.${pkgs.system}.all-ssh-keys-to-age;
      setupSecretsForUsers.deps = ["generateAgeKeysFromSSH"];
      setupSecrets.deps = ["generateAgeKeysFromSSH"];
    };

    # Simulate the a home manager module for sops nix. Actually the secrets are imported through the system
    # but we need to create an api from inside Home Manager
    home-manager.sharedModules = [
      ({
        nixosConfig,
        config,
        ...
      }: {
        options = {
          sops.secrets = mkOption {
            description = "The content of this option passed to the NixOS sops.secrets option";
          };
          getSopsFile = lib.mkOption {
            description = "A helper function to get the path to a sops secret.";
          };
        };
        # Create a wrapper for the getSopsFile function that looks for the correct name
        config.getSopsFile = name: nixosConfig.getSopsFile (hmSecretName config.home.username name);
      })
    ];

    # Import the secrets that are defined inside Home Manager
    sops.secrets = pipe config.home-manager.users [
      # Get a list of name value pairs of all home manager users
      attrsToList

      # map all defined keys in home-manager to system wide keys with the user enabled
      (map (userCfg:
        pipe userCfg.value.sops.secrets [
          # same as above
          attrsToList

          (map (secret: {
            # secret name will be e.g. "hm-secrets/osi/api-keys/open-ai"
            name = hmSecretName userCfg.name secret.name;
            value =
              secret.value
              // {
                # Set the correct user
                owner = userCfg.name;
                # and the correct key
                key = secret.name;
              };
          }))
        ]))

      # transform the sops secret name value pair list to a set of sops secrets
      flatten
      listToAttrs
    ];
  };
}
