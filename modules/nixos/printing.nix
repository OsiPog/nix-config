{pkgs, ...}: {
  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      gutenprint
      # epsonscan2
    ];
  };

  # and avahi for bonjour
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    # nssmdns6 = true;
    openFirewall = true;
  };
}
