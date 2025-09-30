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

  environment.systemPackages = [pkgs.devenv];

  services.nginx.virtualHosts."laravel-application.${config.networking.domain}" = {
    useACMEHost = "${config.networking.domain}-cert";
    forceSSL = true;
    locations = {
      "/" = {
        proxyPass = "http://localhost:8000";
      };
      "/_vite" = {
        proxyPass = "http://localhost:5173";
      };
    };
  };

  security.acme.certs."${config.networking.domain}-cert".extraDomainNames = ["laravel-application.${config.networking.domain}"];

  system.stateVersion = "25.11";
}
