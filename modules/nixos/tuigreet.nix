{
  pkgs,
  config,
  ...
}: {
  environment.systemPackages = [ pkgs.xorg.xauth ];
  services.xserver.displayManager.startx.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      # user needs to authenticate on relogin
      default_session = {
        # https://ryjelsum.me/homelab/greetd-session-choose/
        command = ''${pkgs.greetd.tuigreet}/bin/tuigreet --sessions ${config.services.displayManager.sessionData.desktops}/share/xsessions:${config.services.displayManager.sessionData.desktops}/share/wayland-sessions --xsession-wrapper startx --remember --remember-user-session'';
        user = "greeter";
      };
    };
  };
}
