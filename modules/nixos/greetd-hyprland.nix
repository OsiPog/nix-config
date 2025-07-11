{
  pkgs,
  lib,
  ...
}: {
  programs.hyprland.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      # user needs to authenticate on relogin
      default_session = {
        command = ''          ${lib.getExe pkgs.greetd.tuigreet} \
                    --greeting 'Welcome to NixOS!' \
                    --asterisks \
                    --remember \
                    --remember-user-session \
                    --time \
                    --cmd Hyprland'';
        user = "greeter";
      };
    };
  };
}
