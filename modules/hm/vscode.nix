{
  self,
  pkgs,
  lib,
  inputs,
  config,
  nixosConfig,
  ...
}: let
  inherit (builtins) replaceStrings readFile;
  vscodeExts = inputs.nix-vscode-extensions.extensions.${pkgs.system};
in {
  # Make codium default
  xdg.mimeApps.defaultApplications = lib.attrsets.genAttrs [
    "text/plain"
    "text/x-c"
    "text/x-c++src"
    "text/x-java"
    "text/x-python"
    "text/x-shellscript"
    "application/json"
    "application/xml"
    "application/javascript"
    "application/x-typescript"
    "text/html"
    "text/css"
    "text/x-markdown"
    "text/x-yaml"
    "application/x-php"
    "application/x-ruby"
    "application/x-perl"
  ] (type: "codium.desktop");

  programs.vscode = {
    enable = true;
    package = pkgs.vscodium.overrideAttrs (prev:
      with builtins;
      with lib.strings; {
        # As NIXOS_OZONE_WL is enabled, it is tried here too. But VSCodium shows a warning that is it an
        # unsupported parameter. This hack removes that parameter added by the environment variable.
        preFixup = concatStringsSep "\n" (
          # Filter out the line containing the parameter that causes the warning
          filter
          (str: (match ".*ozone-platform-hint.*" str) == null)
          (splitString "\n" prev.preFixup)
        );
      });
    profiles.default = {
      userSettings = {
        # --- VSCODE ---
        # extra stuff turned off
        "window.commandCenter" = false;
        "workbench.layoutControl.enabled" = false;
        "workbench.editor.showTabs" = "none";
        "window.menuBarVisibility" = "toggle"; # hide menu bar unless alt is pressed
        "workbench.startupEditor" = "none"; # no welcome page
        "workbench.editor.editorActionsLocation" = "hidden"; # hide some buttons on the native title ba
        "security.workspace.trust.enabled" = false; # Trust all workspaces
        "workbench.sideBar.location" = "right";
        "window.confirmSaveUntitledWorkspace" = false;
        # hide title bar
        "window.titleBarStyle" = "native";
        "window.customTitleBarVisibility" = "never";
        # minimap
        "editor.minimap.maxColumn" = 100;
        "editor.minimap.showSlider" = "always";
        "editor.minimap.renderCharacters" = false;
        # Include git files in file tree and file search
        "files.exclude" = {
          "**/.git" = false;
        };
        # zen mode settings
        "zenMode.restore" = true;
        "zenMode.hideStatusBar" = true;
        "zenMode.showTabs" = "none";
        "zenMode.hideLineNumbers" = false;
        "zenMode.fullScreen" = false;
        "zenMode.centerLayout" = false;
        # general extensions
        "extensions.autoUpdate" = false;
        "extensions.autoCheckUpdates" = false;

        # --- Debug ---
        "debug.openDebug" = "neverOpen"; # its really annoying that the debug window opens on breakpoint

        # --- CLINE Assistant ---
        "cline.chromeExecutablePath" = lib.getExe config.programs.chromium.package;

        # --- PHP ---
        "php.debug.executablePath" = lib.getExe pkgs.php83;
        "namespaceResolver.autoSort" = false;

        # --- NIX ---
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "${lib.getExe pkgs.nixd}";
        "nix.serverSettings" = {
          nixd = let
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

        # --- JAVA ---
        # All JDKs used for compiling
        "java.configuration.runtimes" = with pkgs; [
          {
            name = "JavaSE-11";
            path = openjdk11 + "/lib/openjdk";
          }
          {
            name = "JavaSE-17";
            path = openjdk17 + "/lib/openjdk";
          }
          {
            name = "JavaSE-21";
            path = openjdk21 + "/lib/openjdk";
          }
        ];
        "java.jdt.ls.java.home" = pkgs.openjdk + "/lib/openjdk"; # JDK used for the language server
        "java.configuration.detectJdksAtStart" = false; # Do not try to detect JDKs
      };
      # Keybindings
      # `when` makes the keybind only available in certain contexts: more on that here
      # https://code.visualstudio.com/api/references/when-clause-contexts
      keybindings = [
        # --- MISC ---
        {
          # Open the search results as a text file in the editor
          key = "ctrl+enter";
          command = "search.action.openInEditor";
          when = "hasSearchResult && searchViewletFocus";
        }
        {
          # open sidebar
          key = "ctrl+p";
          command = "workbench.action.toggleSidebarVisibility";
        }
        {
          key = "ctrl+shift-t";
          command = "workbench.action.toggleZenMode";
        }

        # --- EXTENSIONS ---
        {
          # open cline (when not yet opened)
          key = "ctrl+o c";
          command = "runCommands";
          when = "!multipleEditorGroups";
          args = {
            commands =
              [
                "cline.openInNewTab" # opens the cline window in a tab
                "workbench.action.moveActiveEditorGroupDown" # moves the tab below the actual code

                # shrink the cline tab a couple of times to a reasonable size
              ]
              ++ (lib.lists.replicate 7 "workbench.action.decreaseViewHeight");
          };
        }
        {
          # close cline
          key = "ctrl+o c";
          command = "runCommands";
          when = "multipleEditorGroups";
          args = {
            commands = [
              "workbench.action.editorLayoutSingle"
              "workbench.action.closeActiveEditor"
            ];
          };
        }

        # --- FOCUS AND TOOLS MODE ---
        # in Focus-Mode, no additional windows and zen mode activated

        # Enable focus mode
        {
          key = "ctrl+shift+t";
          command = "runCommands";
          when = "multipleEditorGroups || panelVisible || sidebarVisible || (editorPartMultipleEditorGroups && multipleEditorGroups)";
          args = {
            commands = [
              # enable zen mode
              "workbench.action.exitZenMode"
              "workbench.action.toggleZenMode"

              # disable panel
              "workbench.action.closePanel"

              # disable sidebar
              "workbench.action.closeSidebar"

              # close cline
              "workbench.action.focusLastEditorGroup"
              "workbench.action.closeActiveEditor"
              "workbench.action.editorLayoutSingle"
            ];
          };
        }
        {
          key = "ctrl+shift+t";
          command = "runCommands";
          when = "!multipleEditorGroups && !panelVisible && !sidebarVisible && !(editorPartMultipleEditorGroups && multipleEditorGroups)";
          args = {
            commands =
              [
                # enable zen mode
                "workbench.action.exitZenMode"
                "workbench.action.toggleZenMode"

                # enable panel
                "workbench.action.closePanel"
                "workbench.action.togglePanel"

                # disable sidebar
                "workbench.action.closeSidebar"

                # enable cline
                "cline.openInNewTab" # opens the cline window in a tab
                "workbench.action.moveActiveEditorGroupDown" # moves the tab below the actual code
                # shrink the cline tab a couple of times to a reasonable size
              ]
              ++ (lib.lists.replicate 3 "workbench.action.decreaseViewHeight")
              ++ [
                # focus the code
                "workbench.action.focusLastEditorGroup"
              ];
          };
        }

        # --- CODE NAVIGATION ---
        {
          # Go to definition
          key = "ctrl+k g";
          command = "editor.action.revealDefinition";
          when = "editorHasDefinitionProvider && editorTextFocus";
        }
        {
          # Go to definition (Godot tools)
          key = "ctrl+k g";
          command = "godotTools.scenePreview.goToDefinition";
          when = "editorLangId == gdscript";
        }
        {
          # Find all references of a symbol
          key = "ctrl+k j";
          command = "references-view.findReferences";
          when = "editorHasReferenceProvider";
        }
        {
          # enforce single colmn layout
          key = "ctrl+shift+c";
          command = "workbench.action.editorLayoutSingle";
        }

        # --- GIT ---
        # Merge conflicts accept
        {
          key = "ctrl+k b";
          command = "merge-conflict.accept.both";
        }
        {
          key = "ctrl+k i";
          command = "merge-conflict.accept.incoming";
        }
        {
          key = "ctrl+k c";
          command = "merge-conflict.accept.current";
        }
        {
          key = "ctrl+k t";
          command = "diffEditor.revert";
        }

        # --- COMMENTS ---
        {
          # Line
          key = "ctrl+/";
          command = "editor.action.commentLine";
          when = "editorTextFocus && !editorReadonly";
        }
        {
          # Block
          key = "ctrl+shift+/";
          command = "editor.action.blockComment";
          when = "editorTextFocus && !editorReadonly";
        }
        # --- DOCBLOCK ---
        {
          # phpDoc
          key = "ctrl+enter";
          command = "phpdoc-generator.generatePHPDoc";
          when = "editorLangId == php";
        }
        {
          # JSDoc
          key = "ctrl+enter";
          command = "docthis.documentThis";
          when = "editorLangId =~ /vue|js|ts|jsx|tsx/";
        }

        # --- IMPORTS ---
        {
          # PHP Imports
          key = "ctrl+o i";
          command = "namespaceResolver.import";
          when = "editorLangId == php";
        }

        # --- DEBUGGING ---
        {
          # Start debugger
          key = "ctrl+o e";
          command = "workbench.action.debug.start";
          when = "debuggersAvailable && !inDebugMode";
        }
        {
          # Stop debugger
          key = "ctrl+o e";
          command = "workbench.action.debug.stop";
          when = "inDebugMode";
        }
        {
          # Contiune when stopped
          key = "ctrl+shift+o";
          command = "workbench.action.debug.continue";
          when = "inDebugMode";
        }
        {
          # Open watch panel
          key = "ctrl+o w";
          command = "workbench.debug.action.focusWatchView";
          when = "inDebugMode";
        }
        {
          # Add a watch expression
          key = "shift+enter";
          command = "workbench.debug.viewlet.action.addWatchExpression";
          when = "watchExpressionsFocused";
        }
        {
          # Remove all watch expressions (removing one by one is really tedious through keyboard)
          key = "shift+backspace";
          command = "workbench.debug.viewlet.action.removeAllWatchExpressions";
          when = "watchExpressionsFocused";
        }
        {
          # Edit a watched expression
          key = "enter";
          command = "debug.renameWatchExpression";
          when = "watchExpressionsFocused";
        }
        {
          # Toggle breakpoint
          key = "ctrl+o t";
          command = "editor.debug.action.toggleBreakpoint";
        }
      ];
      extensions = with vscodeExts;
      with vscode-marketplace; let
        op-vsx = open-vsx;
      in [
        # --- UTILITIES ---
        davidlgoldberg.jumpy2 # jumping cursors with short letter combo
        eamodio.gitlens # useful for git blame inline
        saoudrizwan.claude-dev # llm coding agent
        sleistner.vscode-fileutils # crud for files

        # --- PHP ---
        zobo.php-intellisense # intellisense
        xdebug.php-debug # debugging php applications
        ronvanderheijden.phpdoc-generator # generate php doc comments
        mehedidracula.php-namespace-resolver # php everything namespace

        # --- NIX ---
        jnoortheen.nix-ide # nix language features

        # --- NUSHELL ---
        thenuprojectcontributors.vscode-nushell-lang

        # --- NODE ---
        vue.volar # vue language features
        oouo-diogo-perdigao.docthis # jsdoc

        # --- JAVA ---
        # redhat.java # language features
        vscjava.vscode-java-debug # debugger
        vscjava.vscode-java-dependency # project manager

        # --- GODOT ENGINE ---
        geequlim.godot-tools

        # --- SQL ---
        adpyke.vscode-sql-formatter
      ];
    };
  };

  # Set VSCodium to be git editor
  programs.git.extraConfig = let
    codium = "codium --wait --new-window";
  in {
    core.editor = "codium --wait";
    diff.tool = "vscodium";
    "difftool \"vscodium\"".cmd = codium + " --diff $LOCAL $REMOTE";
    merge.tool = "vscodium";
    "mergetool \"vscodium\"".cmd = codium + " \"$MERGED\"";
  };
}
