{
  pkgs,
  config,
  lib,
  ...
}: let
  repositoryOrigin = "git@github.com:OsiPog/pass.git";

  inherit (builtins) match;
in {
  home.packages = [
    # a script to fetch the password store easily in the correct folder
    (pkgs.writeShellApplication {
      name = "pass-fetch";
      text = ''
        DEST_DIR="${config.programs.password-store.settings.PASSWORD_STORE_DIR}"

        if [ ! -d "$DEST_DIR" ]; then
          git clone "${repositoryOrigin}" "$DEST_DIR"
        else
          pass git pull
          pass git push
        fi
      '';
    })

    (pkgs.wofi-pass.override {
      extensions = exts: [
        exts.pass-otp
      ];
    })
  ];

  programs.password-store = {
    enable = true;
    package = pkgs.pass.withExtensions (exts: [
      exts.pass-otp
    ]);
    settings = {
      PASSWORD_STORE_DIR = "$HOME/.password-store";
    };
  };

  programs.gpg = {
    enable = true;
  };

  services.gpg-agent = {
    enable = true;
    enableScDaemon = true;
    enableSshSupport = true;
  };

  # add plugin to rofi if enabled
  programs.rofi.pass = {
    enable = config.programs.rofi.enable;
  };

  # with wofi-pass we can use wofi to access pass
  home.file.".config/wofi-pass/config".text = ''
    WOFI_PASS_DELAY=0
    PASS_FIELD_USERNAME="user"
    WOFI_PASS_AUTO_ENTER=true
    CMD_TYPE="xargs ydotool type --key-delay=1 --key-hold=1"
  '';
}
