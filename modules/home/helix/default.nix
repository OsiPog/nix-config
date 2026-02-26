{
  pkgs,
  lib,
  flake,
  nixosConfig,
  inputs,
  config,
  ...
}: {
  sops.secrets = {
    "api-keys/anthropic".sopsFile = ./secrets.yaml;
    "intelephense/licence.txt".sopsFile = ./secrets.yaml;
  };

  home.packages = with pkgs; [
    (writeShellApplication {
      name = "helix";
      runtimeInputs = [
        pkgs.helix
      ];
      text = ''
        hx "$@"
      '';
    })
  ];

  programs.helix = {
    enable = true;
    extraPackages = with pkgs; [
      # Nix
      alejandra
      nil
      nixd

      # PHP
      # phpactor
      intelephense

      # Nodejs and friends
      vtsls
      # Extracted language servers from vscode, contains:
      # `vscode-css-language-server`
      # `vscode-html-language-server`
      # `vscode-eslint-language-server` # TODO: This is broken!!
      # `vscode-json-language-server`
      # `vscode-markdown-language-server`
      flake.packages.${pkgs.system}.vscode-langservers-extracted

      # QML
      kdePackages.qtdeclarative # contains `qmlls`

      # ai assistance
      (writeShellApplication {
        name = "lsp-ai";
        runtimeInputs = [pkgs.lsp-ai];
        text = ''
          export ANTHROPIC_API_KEY=${config.getSopsFile "api-keys/anthropic"}
          lsp-ai "$@"
        '';
      })
    ];
    settings = {
      editor = {
        line-number = "relative";
        cursor-shape = {
          insert = "bar";
          select = "underline";
        };
        indent-guides.render = true;
        inline-diagnostics = {
          cursor-line = "hint";
          max-wrap = 0;
        };
        jump-label-alphabet = "arstneiodhqwfpluyzxcvmARSTNEIODHQWFPLUYZXCVM";
        auto-save.after-delay.enable = true;
        lsp = {
          display-progress-messages = true;
        };
      };
      keys = let
        lintCodeScript =
          pkgs.writeShellScript "lint-code"
          /*
          bash
          */
          ''
            set +e # Failing is okay here!
            if command -v eslint; then
              eslint "$1"
            fi
            echo "End of linter output"
          '';

        # Binds in the menu that opens on "+"
        plusBinds = {
          # Open VSCodium
          v = ":sh codium $PWD --goto %{buffer_name}:%{cursor_line}:%{cursor_column}";
          # Format File
          f = ":format";
          # Lint File
          l = ":sh ${lintCodeScript} %{buffer_name}";
          # Format and Lint
          L = [
            ":format"
            ":sh ${lintCodeScript} %{buffer_name}"
          ];
          # Open blame for selected lines
          b = ":sh git blame -L %{selection_line_start},%{selection_line_end} %{buffer_name}";
          # Copy GitHub permalink to current cursor position
          c = ":sh gh repo view --json url | jq -r \".url + \\\"/blob/$(git rev-parse HEAD)/%{buffer_name}#L%{selection_line_start}-L%{selection_line_end}\\\"\" | wl-copy";
        };

        # Binds in the menu that opens on "+" and need select mode
        plusBindsNeedSelection = {
        };
      in {
        normal = {
          g.l = "goto_line_end_newline";
          "+" = plusBinds;
        };
        select = {
          "+" = plusBinds // plusBindsNeedSelection;
        };
      };
    };
    languages = {
      language-server = {
        # Nix
        nixd = {
          config = let
            flakeExpr = "(__getFlake \"github:osipog/nix-config\")";
            pkgsExpr = "(import ${flakeExpr}.inputs.nixpkgs {})";
            currentSystemExpr = "(${flakeExpr}.nixosConfigurations.${nixosConfig.networking.hostName})";
          in {
            autoArchive = true;
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

        intelephense = {
          licenceKey = config.getSopsFile "intelephense/licence.txt";
        };

        # Vue
        # vue-language-server = {
        #   command = lib.getExe pkgs.vue-language-server;
        #   args = ["--stdio"];
        #   config.typescript.tsdk = "${pkgs.typescript}/lib/node_modules/typescript/lib";
        # };

        # Typescript/Javascript/Vue
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
            # "vue-language-server"
            "vscode-eslint-language-server"
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
          language-servers = [
            # "phpactor"
            "intelephense"
          ];
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
          language-servers = [
            "vtsls"
            "vscode-eslint-language-server"
          ];
          formatter = {
            command = "prettier";
            args = ["--parser" "typescript"];
          };
        }
        {
          name = "typescript";
          language-servers = [
            "vtsls"
            "vscode-eslint-language-server"
          ];
          formatter = {
            command = "prettier";
            args = ["--parser" "typescript"];
          };
        }
        {
          name = "sql";
          formatter.command = lib.getExe pkgs.sql-formatter;
        }
        {
          name = "markdown";
          soft-wrap.enable = true;
        }
        {
          name = "typst";
          soft-wrap.enable = true;
        }
      ];
    };
  };

  home.sessionVariables."VISUAL" = "hx";

  programs.lazygit.settings.os.editPreset = "helix";
}
