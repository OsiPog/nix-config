{
  pkgs,
  lib,
  config,
  ...
}: let
  claudeModel = "claude-sonnet-4-6";
in {
  sops = {
    secrets."api-keys/anthropic" = {
      sopsFile = ./secrets.yaml;
    };
    templates.litellm-env = {
      content = ''
        ANTHROPIC_API_KEY=${config.sops.placeholder."api-keys/anthropic"}
      '';
    };
  };

  # proxy for gemini cli to use claude models
  services.litellm = {
    enable = true;
    port = 4235;
    package = pkgs.litellm.overridePythonAttrs (old: rec {
      version = "647e5237a78aa611cba8f6f334bb0274c64ac4d5";
      src = pkgs.fetchFromGitHub {
        owner = "BerriAI";
        repo = "litellm";
        rev = version;
        hash = "sha256-+OvUhKR3LhRTFedicpWPY9L0r2BD3WVvUJpOP1MPrp4=";
      };
    });
    environmentFile = config.sops.templates.litellm-env.path;
    environment = {
      DETAILED_DEBUG = "True";
    };
    settings = {
      general_settings = {
        master_key = "sk-1234";
        allow_requests_on_db_unavailable = true;
      };
      litellm_settings = {
        api_base = "http://localhost:${toString config.services.litellm.port}";
      };
      model_list = [
        {
          model_name = claudeModel;
          litellm_params = {
            model = "anthropic/${claudeModel}";
            api_key = "os.environ/ANTHROPIC_API_KEY";
          };
        }
      ];
      router_settings.model_group_alias = {"gemini-2.5-pro" = claudeModel;};
    };
  };

  home-manager.sharedModules = [
    ({
      nixosConfig,
      config,
      pkgs,
      ...
    }: let
      heygptWrapper = pkgs.writeShellApplication {
        name = "heygpt";
        runtimeInputs = [pkgs.heygpt];
        text = ''
          OPENAI_API_BASE="https://api.openai.com/v1" \
          OPENAI_API_KEY=$(cat ${config.getSopsFile "api-keys/open-ai"}) \
          heygpt --model "''${HEYGPT_MODEL:-gpt-4o}" "$@"
        '';
      };
    in {
      home = {
        packages = [
          heygptWrapper # terminal gpt integration
        ];

        sessionVariables = {
          GOOGLE_GEMINI_BASE_URL = nixosConfig.services.litellm.settings.litellm_settings.api_base;
          GEMINI_API_KEY = nixosConfig.services.litellm.settings.general_settings.master_key;
        };
      };

      sops.secrets = {
        "api-keys/open-ai" = {
          sopsFile = ./secrets.yaml;
        };
        "api-keys/anthropic" = {
          sopsFile = ./secrets.yaml;
        };
      };

      programs.claude-code = {
        enable = true;
        memory.text = ''
          Run any command that is not part of core linux with `nix run nixpkgs#<package-name>`
        '';
        settings = {
          apiKeyHelper = "cat " + (config.getSopsFile "api-keys/anthropic");
        };
      };

      programs.gemini-cli = {
        enable = true;
      };
    })
  ];
}
