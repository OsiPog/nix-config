{
  config,
  hostName,
  lib,
  ...
}: let
  inherit (lib) mkIf;

  cfg = config.network.services.vsftpd;

  certName = "base-domain-cert";
  certCfg = config.security.acme.certs.${certName};
in {
  options.network.services.vsftpd = config.lib.network.mkServiceOptions;
  config = mkIf (cfg.enable && cfg.host == hostName) {
    assertions = [
      {
        assertion = !cfg.reverseProxy.enable;
        message = "Due to limitations in the FTP protocol, vsftpd cannot be reverse proxied on a subdomain.";
      }
    ];
    services.vsftpd = {
      enable = true;

      # Local users should be able to login
      writeEnable = true;
      localUsers = true;
      chrootlocalUser = true;
      allowWriteableChroot = true;

      # SSL
      ssl_tlsv1 = true;
      rsaCertFile = certCfg.directory + "/cert.pem";
      rsaKeyFile = certCfg.directory + "/key.pem";
      forceLocalLoginsSSL = true;

      extraConfig = ''
        ssl_enable=YES
        pasv_enable=YES
        pasv_min_port=40000
        pasv_max_port=40100
        listen_port=${toString cfg.port}
      '';
    };

    networking.firewall = {
      allowedTCPPorts = [cfg.port];
      allowedTCPPortRanges = [
        {
          from = 40000;
          to = 40100;
        }
      ];
    };

    # The FTP user
    sops.secrets."pass-hashes/file-sharer" = {neededForUsers = true;};
    users.users.file-sharer = {
      isNormalUser = true;
      hashedPasswordFile = config.getSopsFile "pass-hashes/file-sharer";
      createHome = true;
    };

    # SSL certificate
    sops.secrets."acme/porkbun" = {};
    security.acme = {
      acceptTerms = true;
      defaults.email = "osibluber@pm.me";
      certs.${certName} = {
        inherit (config.networking) domain;
        dnsProvider = "porkbun";
        environmentFile = config.getSopsFile "acme/porkbun";
      };
    };
  };
}
