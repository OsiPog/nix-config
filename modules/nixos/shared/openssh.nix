{...}: {
  services.openssh = {
    enable = true;
    openFirewall = true;
    ports = [22];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
}
