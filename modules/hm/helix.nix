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
    extraPackages = with pkgs; [
      nixd
    ];
    settings = {
      editor = {
        line-number = "relative";
        cursor-shape.insert = "bar";
        indent-guides.render = true;
        inline-diagnostics.cursor-line = "error";
        inline-diagnostics.other-lines = "error";
        jump-label-alphabet = "arstneiodhqwfpluyzxcvm";
        auto-save.after-delay.enable = true;
      };
    };
    languages = {
      language-servers = {
        typescript-language-server = with pkgs.nodePackages; {
          command = lib.getExe typescript-language-server;
          args = [ "--stdio" "--tsserver-path=${typescript}/lib/node_modules/typescript/lib" ];
        };
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
      };
      language = [
        {
          name = "nix";
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
          language-servers = ["typescript-language-server"];
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
          debugger = {
            name = "vscode-php-debug";
            transport = "stdio";
            command = lib.getExe pkgs.nodejs;
            args = [ (inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace.xdebug.php-debug + "/share/vscode/extensions/xdebug.php-debug/out/phpDebug.js") ];
            templates = [{
              name = "Listen for XDebug";
              request = "launch";
              completion = "ignored";
              # args = [];
            }];
          };
        }
      ];
    };
  };

  home.sessionVariables."EDITOR" = "hx";
}
