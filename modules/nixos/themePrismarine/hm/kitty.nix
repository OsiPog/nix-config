{
  nixosConfig,
  lib,
  config,
  ...
}: {
  # Terminal
  programs.kitty.settings = lib.mkIf config.programs.kitty.enable {
    # Text is moved a bit inwards, like that its not so close to the border
    window_padding_width = nixosConfig.prismarineTheme.padding;
  };
}
