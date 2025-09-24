{
  pkgs,
  lib,
  flake,
  nixosConfig,
  inputs,
  ...
}: {
  programs.helix = {
    enable = true;
    extraPackages = with pkgs; [
      # Nix
      alejandra
      nil
      nixd

      # PHP
      phpactor

      # Nodejs and friends
      vtsls

      # QML
      kdePackages.qtdeclarative # contains `qmlls`
    ];
    settings = {
      editor = {
        line-number = "relative";
        cursor-shape.insert = "bar";
        indent-guides.render = true;
        inline-diagnostics = {
          cursor-line = "hint";
          max-wrap = 0;
        };
        jump-label-alphabet = "arstneiodhqwfpluyzxcvm";
        auto-save.after-delay.enable = true;
      };
      keys.normal.space.v = ":sh codium $PWD --goto %{buffer_name}:%{cursor_line}:%{cursor_column}";
    };
    languages = {
      language-server = {
        # Nix
        nixd = {
          config = let
            flakeExpr = "(builtins.getFlake \'\'${flake}\'\')";
            pkgsExpr = "(import ${flakeExpr}.inputs.nixpkgs {})";
            currentSystemExpr = flakeExpr + ".nixosConfigurations.${nixosConfig.networking.hostName}";
          in {
            nixpkgs.expr = pkgsExpr;
            options = {
              nixos.expr = "${currentSystemExpr}.options";
              home-manager.expr = "${currentSystemExpr}.options.home-manager.users.type.getSubOptions {}";
              devenv.expr = "${flakeExpr}.lib.devenv.allDevenvOptions";
            };
          };
        };

        phpactor = {
          command = "phpactor";
          args = ["language-server"];
        };

        # Vue
        # vue-language-server = {
        #   command = lib.getExe pkgs.vue-language-server;
        #   args = ["--stdio"];
        #   config.typescript.tsdk = "${pkgs.typescript}/lib/node_modules/typescript/lib";
        # };

        # Typescript
        vtsls = {
          command = "vtsls";
          args = ["--stdio"];
          config = {
            typescript = {
              # tsdk = "${pkgs.typescript}/lib/node_modules/typescript/lib";
              # npm = "${pkgs.nodejs}/bin/npm";
              tsserver = {
                nodePath = lib.getExe pkgs.nodejs;
                log = "normal";
                watchOptions = {
                  watchFile = "useFsEvents";
                  watchDirectory = "useFsEvents";
                  fallbackPolling = "priorityPollingInterval";
                };
              };
            };
            vtsls.tsserver.globalPlugins = [
              {
                name = "@vue/typescript-plugin";
                languages = ["vue"];
                configNamespace = "typescript";
                location = "${
                  flake.packages.${pkgs.system}.vue-typescript-plugin
                }/lib/node_modules/@vue/typescript-plugin";
              }
            ];
          };
        };
      };
      language = [
        {
          name = "nix";
          language-servers = [
            "nixd"
            "nil"
          ];
          file-types = ["nix"];
          formatter = {
            command = "alejandra";
            args = ["-q"];
          };
          auto-format = true;
          indent = {
            tab-width = 2;
            unit = "  ";
          };
        }
        {
          name = "vue";
          file-types = ["vue"];
          language-servers = [
            "vtsls"
            "vue-language-server"
          ];
          scope = "source.vue";
          roots = ["package.json"];
          auto-format = false;
          indent = {
            tab-width = 4;
            unit = "    ";
          };
        }
        {
          name = "php";
          file-types = ["php"];
          language-servers = ["phpactor"];
          debugger = {
            name = "vscode-php-debug";
            transport = "stdio";
            command = lib.getExe pkgs.nodejs;
            args = [
              (
                inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace.xdebug.php-debug
                + "/share/vscode/extensions/xdebug.php-debug/out/phpDebug.js"
              )
            ];
            templates = [
              {
                name = "Listen for XDebug";
                request = "launch";
                completion = ["ignored"];
                args = {};
              }
            ];
          };
        }
        {
          name = "javascript";
          language-servers = ["vtsls"];
        }
        {
          name = "typescript";
          language-servers = ["vtsls"];
        }
        {
          name = "sql";
          formatter.command = lib.getExe pkgs.sql-formatter;
        }
      ];
    };
  };

  home.sessionVariables."EDITOR" = "hx";
}
