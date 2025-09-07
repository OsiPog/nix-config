{...}: {
  services.tailscale = {
    enable = true;
    openFirewall = true;
    interfaceName = "sculk";
  };
}
