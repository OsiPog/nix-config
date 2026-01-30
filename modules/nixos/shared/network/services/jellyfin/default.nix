{
  config,
  lib,
  flake,
  hostName,
  ...
}: let
  inherit (lib) mkIf mkDefault;
  inherit (flake.lib) mkNetworkHostServiceModule;
  inherit (config.lib.network) getServiceVariables getAddress;

  inherit
    (getServiceVariables "jellyfin")
    serviceName
    portName
    networkCfg
    cfg
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      configEnable = {
        ports.${portName}.port = mkDefault 8096;
      };
    }))

    flake.inputs.jellarr.nixosModules.default
  ];

  config = mkIf (networkCfg.enable && cfg.enable) {
    sops = {
      secrets = {
        "jellyfin/admin-pass" = {
          owner = config.services.jellyfin.user;
          sopsFile = ./secrets.yaml;
        };
        "jellyfin/api-key" = {
          owner = config.services.jellyfin.user;
          sopsFile = ./secrets.yaml;
        };
      };
      templates.jellarr-env = {
        content = ''
          JELLARR_API_KEY=${config.sops.placeholder."jellyfin/api-key"}
        '';
        owner = config.services.jellyfin.user;
      };
    };

    services.jellyfin = {
      enable = true;
      dataDir = cfg.stateDir;
    };

    services.jellarr = {
      enable = true;
      environmentFile = config.sops.templates.jellarr-env.path;
      inherit (config.services.jellyfin) user group;
      dataDir = "${cfg.stateDir}/jellarr";
      bootstrap = {
        enable = true;
        apiKeyFile = config.getSopsFile "jellyfin/api-key";
      };
      config = {
        version = mkDefault 1;
        base_url = getAddress {
          protocol = "https";
          inherit portName;
          inherit hostName;
        };
        system = {};
        startup.completeStartupWizard = true;
        users = [
          {
            name = "jellyfin-admin";
            passwordFile = config.getSopsFile "jellyfin/admin-pass";
            policy = {
              isAdministrator = true;
              loginAttemptsBeforeLockout = 3;
            };
          }
        ];
      };
    };
  };
}
