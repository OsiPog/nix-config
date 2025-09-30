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
  ];

  networking.firewall.allowedTCPPorts = [5173];

  services.nginx.virtualHosts."laravel-application.${config.networking.domain}" = {
    useACMEHost = "${config.networking.domain}-cert";
    forceSSL = true;
    locations = {
      "/".proxyPass = "http://localhost:8000";
    };
  };

  security.acme.certs."${config.networking.domain}-cert".extraDomainNames = ["laravel-application.${config.networking.domain}"];

  system.stateVersion = "25.11";
}
