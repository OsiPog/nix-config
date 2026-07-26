{
  config,
  lib,
  flake,
  ...
}: let
  inherit (lib) mkIf mkDefault mkForce;
  inherit (lib.attrsets) getAttrs;
  inherit (flake.lib) mkNetworkHostServiceModule mkSharedSecrets mkGroupsFromSecretsWithMembers;
  inherit (config.lib.network) getServiceVariables;

  inherit
    (getServiceVariables "llamacpp")
    serviceName
    portName
    networkCfg
    cfg
    ports
    ;
in {
  imports = [
    (mkNetworkHostServiceModule {inherit serviceName;} ({...}: {
      configEnable = {
        ports.${portName} = {
          protocol = "http";
          port = mkDefault 7999;
        };
      };

      provideEnable = {
        openai-api = rec {
          secrets = mkSharedSecrets [apiKeySecretName] ./secrets.yaml;
          url = ports.${portName}.address "proxyProtocol://domain/v1";
          apiKeySecretName = "llamacpp/api-key";
          displayName = "llama.cpp";
        };
      };
    }))
  ];

  config = mkIf (networkCfg.enable && cfg.enable) (
    let
      openaiApi = cfg.provide.openai-api;
      secrets = getAttrs [openaiApi.apiKeySecretName] openaiApi.secrets;
    in {
      sops = {inherit secrets;};

      # Static system user instead of the upstream DynamicUser, so the api-key
      # secret can be read via group membership (see lldap for the same pattern).
      users.users.llamacpp = {
        group = "llamacpp";
        isSystemUser = true;
      };
      users.groups = {llamacpp = {};} // mkGroupsFromSecretsWithMembers secrets ["llamacpp"];

      systemd.services.llama-cpp.serviceConfig = {
        DynamicUser = mkForce false;
        User = "llamacpp";
        Group = "llamacpp";
      };

      services.llama-cpp = {
        enable = true;
        settings = {
          host = "0.0.0.0";
          port = ports.${portName}.port;
          api-key-file = config.getSopsFile openaiApi.apiKeySecretName;
          # model / hf-repo etc. configured per-host
        };
      };
    }
  );
}
