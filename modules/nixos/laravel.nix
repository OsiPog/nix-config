{
  config,
  lib,
  ...
}: let
  hostConfig = config;
  port = 8000;
in {
  containers.laravel = {
    autoStart = true;
    bindMounts = {
      "/srv/laravel" = {
        hostPath = "/srv/laravel";
        isReadOnly = false;
      };
    };
    config = {
      pkgs,
      config,
      ...
    }: let
      phpPackage = pkgs.php.buildEnv {
        extensions = {
          enabled,
          all,
        }:
          with all; enabled ++ [memcached ctype curl dom fileinfo filter mbstring openssl pdo session tokenizer xml];
        extraConfig = ''
          memory_limit = 256M
        '';
      };
    in {
      users = {
        users.php = {
          isNormalUser = true;
          createHome = true;
          group = "php";
        };
        groups.php = {};
      };

      services.phpfpm.pools.default = {
        user = "php";
        group = "php";
        phpPackage = phpPackage;
        settings = {
          "listen.owner" = config.services.nginx.user;
          "listen.group" = config.services.nginx.group;

          # you should probably take some time to understand these values, see https://www.php.net/manual/en/install.fpm.configuration.php
          "pm" = "dynamic";
          "pm.max_children" = 8;
          "pm.start_servers" = 2;
          "pm.min_spare_servers" = 2;
          "pm.max_spare_servers" = 4;
          "pm.max_requests" = 500;
          "request_terminate_timeout" = 300;
        };
      };

      # Copied and adapted from https://laravel.com/docs/12.x/deployment#nginx
      services.nginx = {
        enable = true;
        virtualHosts."localhost" = {
          root = "/srv/laravel/public";
          listen = [
            {
              inherit port;
              addr = "*";
            }
          ];
          locations = let
            suppressLog = {
              extraConfig = ''
                access_log off;
                log_not_found off;
              '';
            };
          in {
            "/".tryFiles = "try_files $uri $uri/ /index.php?$query_string";
            "= /favicon.ico" = suppressLog;
            "= /robots.txt" = suppressLog;
            "~ ^/index\.php(/|$)".extraConfig = ''
              fastcgi_split_path_info ^(.+\.php)(/.+)$;
              fastcgi_pass unix:${config.services.phpfpm.pools.default.socket};
              include ${pkgs.nginx}/conf/fastcgi_params;
              include ${pkgs.nginx}/conf/fastcgi.conf;
              fastcgi_hide_header X-Powered-By;
            '';
          };
          extraConfig = ''
            add_header X-Frame-Options "SAMEORIGIN";
            add_header X-Content-Type-Options "nosniff";

            index index.php;

            charset utf-8;

            error_page 404 /index.php;
          '';
        };
      };

      system.stateVersion = hostConfig.system.stateVersion;
    };
  };
}
