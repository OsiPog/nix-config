{
  pkgs,
  lib,
  self,
  nixosConfig,
  ...
}: {
  programs.helix = {
    enable = true;
    settings = {
      editor = {
        line-number = "relative";
        cursor-shape.insert = "bar";
        indent-guides.render = true;
        inline-diagnostics.cursor-line = "error";
        inline-diagnostics.other-lines = "error";
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
      ];
    };
  };
}