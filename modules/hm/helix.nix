{
  pkgs,
  lib,
  self,
  nixosConfig,
  inputs,
  ...
}: {
  programs.helix = {
    enable = true;
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
    };
    languages = {
      language-server = {
        # Nix
        nil.command = lib.getExe pkgs.nil;
        nixd = {
          command = lib.getExe pkgs.nixd;
          config = let
            flakeExpr = "(builtins.getFlake \'\'${self}\'\')";
            pkgsExpr = "(import ${flakeExpr}.inputs.nixpkgs {})";
            currentSystemExpr = flakeExpr + ".nixosConfigurations.${nixosConfig.networking.hostName}";
          in {
            formatting = {
              command = ["${lib.getExe pkgs.alejandra}"];
            };
            nixpkgs.expr = pkgsExpr;
            options = {
              nixos.expr = "${currentSystemExpr}.options";
              home-manager.expr = "${currentSystemExpr}.options.home-manager.users.type.getSubOptions {}";
              devenv.expr = "${flakeExpr}.lib.devenv.allDevenvOptions";
            };
          };
        };

        # PHP
        phpactor = {
          command = lib.getExe pkgs.phpactor;
          args = ["language-server"];
        };

        # Vue
        vue-language-server = {
          command = lib.getExe pkgs.vue-language-server;
          args = ["--stdio"];
          config.typescript.tsdk = "${pkgs.typescript}/lib/node_modules/typescript/lib";
        };

        # Typescript
        vtsls = {
          command = lib.getExe pkgs.vtsls;
          args = ["--stdio"];
          config = {
            typescript = {
              tsdk = "${pkgs.typescript}/lib/node_modules/typescript/lib";
              npm = "${pkgs.nodejs}/bin/npm";
              tsserver = {
                nodePath = lib.getExe pkgs.nodejs;
                log = "normal";
              };
            };
            vtsls.tsserver.globalPlugins = [{
              name = "@vue/typescript-plugin";
              languages = ["vue"];
              configNamespace = "typescript";
              location = "${self.packages.${pkgs.system}.vue-typescript-plugin}/lib/node_modules/@vue/typescript-plugin";
            }];
          };
        };
      };
      language = [
        {
          name = "nix";
          language-servers = ["nixd" "nil"];
          file-types = ["nix"];
          auto-format = false;
          formatter = {
            command = lib.getExe pkgs.alejandra;
            args = ["-q"];
          };
          indent = {
            tab-width = 2;
            unit = "  ";
          };
        }
        {
          name = "vue";
          file-types = ["vue"];
          language-servers = [ "vtsls" ];
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
            args = [(inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace.xdebug.php-debug + "/share/vscode/extensions/xdebug.php-debug/out/phpDebug.js")];
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
      ];
    };
  };

  home.sessionVariables."EDITOR" = "hx";
}
