{
  config,
  lib,
  flake,
  hostName,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  inherit (flake.lib) mkServiceOptionsModule;

  serviceName = "vsftpd";
  networkCfg = config.network;
  cfg = networkCfg.hosts.${hostName}.services.${serviceName};

  certCfg = config.security.acme.certs.default;
in {
  imports = [
    (mkServiceOptionsModule serviceName {})
  ];
  config = mkMerge [
    {
    }
    (mkIf (networkCfg.enable && cfg.enable) {
      # assertions = [
      #   {
      #     assertion = !cfg.reverseProxy.enable;
      #     message = "Due to limitations in the FTP protocol, vsftpd cannot be reverse proxied on a subdomain.";
      #   }
      # ];
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
          pasv_min_port=${toString cfg.ports.passive.portRange.from}
          pasv_max_port=${toString cfg.ports.passive.portRange.to}
          listen_port=${toString cfg.ports.control.port}
        '';
      };

      networking.firewall = {
        allowedTCPPorts = [cfg.ports.control.port];
        allowedTCPPortRanges = [cfg.ports.passive.portRange];
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
        certs.default = {
          inherit (config.networking) domain;
          dnsProvider = "porkbun";
          environmentFile = config.getSopsFile "acme/porkbun";
        };
      };
    })
  ];
}
