{ flake, config, ... }:
{
  imports = with flake.nixosModules; [
    shared

    disko-basic

    # ../../users/leaf
  ];

  # state.host.ssh = {
  #   public-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAcSqngrHbdtiCGzPmt6peImIQfYek/WLcaXIwrhN5oS root@haunt-muskie";
  #   allow-connections-from = ["biome-fest"];
  # };
  #
  users.users.root.openssh.authorizedKeys.keyFiles = [
    ../biome-fest/id_ed25519.pub
  ];

  services.openssh.enable = true;

  networking = {
    domain = "kazuka.zip";
    firewall.allowedTCPPorts = [
      22
      443
    ];
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts = {
      "test.${config.networking.domain}" = {
        useACMEHost = "porkbun-cert2";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:8000";
        };
      };
      "@.${config.networking.domain}" = {
        useACMEHost = "porkbun-cert";
        forceSSL = true;
        # locations."/" = {

        # };
      };
    };
  };

  users.users.nginx.extraGroups = [ "acme" ];

  sops.secrets."acme/porkbun" = { };

  security.acme = {
    acceptTerms = true;
    defaults.email = "osibluber@pm.me";
    certs = {
      porkbun-cert = {
        inherit (config.networking) domain;
        dnsProvider = "porkbun";
        environmentFile = config.getSopsFile "acme/porkbun";
      };
      porkbun-cert2 = {
        domain = "test.kazuka.zip";
        dnsProvider = "porkbun";
        environmentFile = config.getSopsFile "acme/porkbun";
      };
    };
  };

  services.forgejo = {
    enable = true;
    settings = {
      server = {
        HTTP_PORT = 8000;
      };
    };
  };

  # services.headscale = {
  #   enable = true;
  #   port = 1001;
  #   settings = {
  #     server_url = "http://127.0.0.1:1002";
  #     dns = {
  #       base_domain = "kazuka.zip";
  #       nameservers.global = [
  #         "1.1.1.1"
  #         "1.0.0.1"
  #         "2606:4700:4700::1111"
  #         "2606:4700:4700::1001"
  #       ];
  #     };
  #     log.level = "debug";

  #   };
  # };

  system.stateVersion = "25.11";
}
