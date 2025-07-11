{nixosConfig, ...}: {
  stylix.targets.wofi.enable = false;

  programs.wofi = {
    settings = {
      allow_images = true;
      prompt = "";
    };
    style = ''
      #window {
        font-family: "${nixosConfig.stylix.fonts.monospace.name}";
        font-size: ${toString nixosConfig.stylix.fonts.sizes.popups}px;
      }

      #window #outer-box {
        margin-top: 15px;
        margin-right: 15px;
        margin-left: 15px;
      }

      #input {
        margin-bottom: 10px;
        border-radius: ${toString nixosConfig.prismarineTheme.border-radius}px;
        font-size: 1.5rem;
        min-height: 2rem;
      }

      #inner-box {
        padding-bottom: 10px;
      }

      #entry {
        margin-bottom: 5px;
        margin-top: 5px;
        border-radius: ${toString nixosConfig.prismarineTheme.border-radius}px;
        font-size: 1.3rem
      }

      .drun-icon {
        margin-right: 8px;
        margin-left: 5px;
      }

      expander {
        margin-left: -16px;
      }
    '';
  };
}
