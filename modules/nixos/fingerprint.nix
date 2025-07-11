{...}: {
  # enable fprintd but disable the pam sudo module
  services.fprintd.enable = true;
  security.pam.services = {
    sudo.fprintAuth = false;
    polkit-1.fprintAuth = false;
    cups.fprintAuth = false;
    greetd.fprintAuth = false;
  };
}
