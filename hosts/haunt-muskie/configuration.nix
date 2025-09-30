{
  flake,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = with flake.nixosModules; [
    ./hardware-configuration.nix
    shared

    disko-basic
  ];

  environment.systemPackages = with pkgs; [
    devenv
    helix
    (php83.buildEnv {
      extensions = {
        enabled,
        all,
      }:
        enabled
        ++ (with all; [
          ctype
          curl
          dom
          fileinfo
          filter
          mbstring
          openssl
          pdo
          session
          tokenizer
          xml
          xdebug
        ]);
    })
  ];

  services.nginx.virtualHosts."laravel-application.${config.networking.domain}" = {
    useACMEHost = "${config.networking.domain}-cert";
    forceSSL = true;
    root = "/home/leaf/laravel/public";
    locations = {
      "/" = {
        tryFiles = "$uri $uri/ /index.php?$query_string";
      };
    };
  };

  security.acme.certs."${config.networking.domain}-cert".extraDomainNames = ["laravel-application.${config.networking.domain}"];

  system.stateVersion = "25.11";
}
