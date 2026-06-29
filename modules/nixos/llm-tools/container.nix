{
  flake,
  inputs,
  config,
  pkgs,
  ...
}: let
  inherit (flake.lib.${pkgs.system}) mkBashScript;
in {
  environment.systemPackages = [
    (mkBashScript {file = ./enter-claude-container.sh;})
    (mkBashScript {file = ./git-sync-agents-data.sh;})
  ];

  sops.secrets."api-keys/anthropic" = {
    sopsFile = ./secrets.yaml;
    mode = "0440";
    group = "agents";
  };

  users.groups.agents.gid = 1923;

  # agents vm data
  systemd.tmpfiles.rules = [
    "d /mnt/agents-data 0770 root users"
  ];

  networking = {
    nat.enable = true; # needed for the kernel settings so NAT works
    nftables = {
      enable = true;
      ruleset =
        /*
        bash, not bash but highlight looks good
        */
        ''
          # route from interface ve-agents to ethernet or wifi interface using NAT
          table inet nat {
            chain postrouting {
              type nat hook postrouting priority 100;
              iifname ve-agents masquerade
            }
          }

          # only allow specific traffic to go through ve-agents
          table inet filter {
            chain forward {
              # allow everything be default
              type filter hook forward priority 0; policy accept;

              # if we come from ve-agents goto this custom chain
              iifname ve-agents jump ve-agents-forward;
            }

            chain ve-agents-forward {
              # allow already established connections
              ct state established,related accept

              # allow anthropic
              ip daddr 160.79.104.10 tcp dport 443 accept
              ip6 daddr 2607:6bc0::10 tcp dport 443 accept
              # allow cloudflare dns
              ip daddr 1.1.1.1 udp dport 53 accept
              ip6 daddr 2606:4700:4700::1111 udp dport 53 accept

              # reject everything else
              reject
            }
          }
        '';
    };
  };

  containers.agents = let
    hostConfig = config;
  in {
    autoStart = false;
    restartIfChanged = true;
    privateNetwork = true;
    hostAddress = "10.0.0.1";
    localAddress = "10.0.0.2";
    bindMounts = {
      data = {
        hostPath = "/mnt/agents-data";
        mountPoint = "/data";
        isReadOnly = false;
      };
      # apiKey = {
      #   hostPath = config.getSopsFile "api-keys/anthropic";
      #   mountPoint = "/api-key";
      # };
    };
    config = {
      pkgs,
      config,
      ...
    }: {
      imports = [
        (flake.lib.mkUserModule "claude")
        inputs.home-manager.nixosModules.default
      ];

      environment.systemPackages = with pkgs; [
        curl
        python3
        jq
        ripgrep
      ];

      networking.defaultGateway = "10.0.0.1";
      networking.nameservers = ["1.1.1.1"];

      users.groups.agents = {
        inherit (hostConfig.users.groups.agents) gid;
        members = ["claude"];
      };

      home-manager.users.claude = {
        programs.git = {
          enable = true;
          settings.user = {
            name = "Claude";
            email = "noreply@anthropic.com";
          };
        };

        programs.claude-code = {
          enable = true;
          package = inputs.claude-code-nix.packages.${pkgs.system}.default;
          memory.text = ''
            You are in a sandboxed environment.
            Any network request will be rejected.

            In every session, always load the 'caveman' skill.

            AFTER EVERY CHANGE: commit your changes!
          '';
          # settings = {
          #   apiKeyHelper = "cat /api-key";
          # };
        };

        home.file.".claude/skills/caveman".source = "${inputs.caveman}/skills/caveman";

        home.stateVersion = config.system.stateVersion;
      };

      system.stateVersion = "26.05";
    };
  };
}
