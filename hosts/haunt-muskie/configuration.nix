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

  services.phpfpm.pools.laravel = {
    user = "laravel";
    settings = {
      "listen.owner" = config.services.nginx.user;
      "pm" = "dynamic";
      "pm.max_children" = 32;
      "pm.max_requests" = 500;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 2;
      "pm.max_spare_servers" = 5;
      "php_admin_value[error_log]" = "stderr";
      "php_admin_flag[log_errors]" = true;
      "catch_workers_output" = true;
    };
    phpPackage = pkgs.php.buildEnv {
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
    };
  };

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
        fastcgi_pass unix:${config.services.phpfpm.pools.laravel.socket};
        include ${pkgs.nginx}/conf/fastcgi.conf;
        fastcgi_hide_header X-Powered-By;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
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

  users.users.laravel = {
    isSystemUser = true;
    group = "laravel";
  };
  users.groups.laravel = {};

  security.acme.certs."${config.networking.domain}-cert".extraDomainNames = ["laravel-application.${config.networking.domain}"];

  system.stateVersion = "25.11";
}
