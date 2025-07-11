{
  pkgs,
  inputs,
  ...
}: {
  imports = [inputs.nvf.homeManagerModules.default];

  programs.nvf = {
    enable = true;
    settings = {
      # Documentation: https://notashelf.github.io/nvf/index.xhtml
      vim = {
        languages = {
          nix.enable = true;
          sql.enable = true;
          ts.enable = true;
          markdown.enable = true;
          html.enable = true;
          php.enable = true;
        };
        lazy.plugins = {
          "telescope.nvim" = {
            package = pkgs.vimPlugins.telescope-nvim;
          };
          "plenary.nvim" = {
            package = pkgs.vimPlugins.plenary-nvim;
          };
        };
        globals.mapleader = " ";
        keymaps = [
          {
            key = "<leader>ff";
            mode = ["n"];
            action = ":Telescope find_files<CR>";
            silent = true;
            desc = "Opens a Telescope prompt to find files within the current working directory.";
          }
          {
            key = "<leader>fg";
            mode = ["n"];
            action = ":Telescope live_grep<CR>";
            silent = true;
            desc = "Performs a live grep search to find text within files.";
          }
          {
            key = "<leader>fb";
            mode = ["n"];
            action = ":Telescope buffers<CR>";
            silent = true;
            desc = "Lists open buffers for quick switching.";
          }
          {
            key = "<leader>fh";
            mode = ["n"];
            action = ":Telescope help_tags<CR>";
            silent = true;
            desc = "Searches through Neovim's help tags.";
          }
          {
            key = "<leader>fo";
            mode = ["n"];
            action = ":Telescope oldfiles<CR>";
            silent = true;
            desc = "Lists recently opened files.";
          }
          {
            key = "<leader>fe";
            mode = ["n"];
            action = ":Telescope file_browser<CR>";
            silent = true;
            desc = "Opens a file browser to traverse directories (might require telescope-file-browser.nvim).";
          }
        ];
      };
    };
  };
}
