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
    (pkgs.php.buildEnv {
      extensions = {
        enabled,
        all,
      }:
        enabled
        ++ (with all; [
          xdebug
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
        ]);
      extraConfig = ''
        xdebug.mode=debug
      '';
    })
  ];

  services.nginx.virtualHosts."laravel-application.${config.networking.domain}" = {
    useACMEHost = "${config.networking.domain}-cert";
    forceSSL = true;
    root = "/srv/laravel/public";
    locations = {
      "/".tryFiles = "$uri $uri/ /index.php?$query_string";
      "= /favicon.ico".extraConfig = ''
        access_log off;
        log_not_found off;
      '';
      "= /robots.txt".extraConfig = ''
        access_log off;
        log_not_found off;
      '';
      "~ ^/index\.php(/|$)".extraConfig = ''
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
      '';
      "~ /\.(?!well-known).*".extraConfig = "deny all;";
    };
    extraConfig = ''
      add_header X-Frame-Options "SAMEORIGIN";
      add_header X-Content-Type-Options "nosniff";

      index index.php;

      charset utf-8;

      error_page 404 /index.php;
    '';
  };

  security.acme.certs."${config.networking.domain}-cert".extraDomainNames = ["laravel-application.${config.networking.domain}"];

  system.stateVersion = "25.11";
}
