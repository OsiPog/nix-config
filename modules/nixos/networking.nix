{
  pkgs,
  config,
  ...
}: {
  # A fix for docker
  # environment.etc."resolv.conf".text = "nameserver 8.8.8.8";

  networking = let
    wireguardPort = 51820;
  in {
    networkmanager = {
      enable = true;
    };

    firewall = {
      enable = true;
      allowedTCPPorts = [
        8000
        9003
        18000
      ];
      allowedUDPPorts = [
        wireguardPort
      ];
      # allowedUDPPortRanges = [
      #   { from = 4000; to = 4007; }
      #   { from = 8000; to = 8010; }
      # ];
    };
    wireguard.interfaces = {
      # TODO: Internet connection in home network incredibly slow, printer doesnt work when active
      # sculk = {
      #   ips = [ "10.12.21.201/24" ]; # IP address and subnet of tunnel interface
      #   listenPort = wireguardPort; # if not specified it would be random

      #   privateKeyFile = config.getSopsFile "wireguard/biome-fest/private-key";

      #   mtu = 500;

      #   peers = [{
      #     name = "fritzbox";
      #     publicKey = "9NEq+5caoXWXidnDeizGKaii0/1RZ1Ho0qICRybSIQE=";
      #     presharedKeyFile = config.getSopsFile "wireguard/biome-fest/psk";
      #     # Route all traffic in the specific subnet through the tunnel
      #     allowedIPs = [ "10.12.21.0/24" ];
      #     # this here would route ALL traffic through the tunnel
      #     # Problem: if the tunnel is blocked, no internet access at all is possible
      #     # allowedIPs = [ "10.12.21.0/24" "0.0.0.0/0" ];
      #     endpoint = "h8wkgwwxnvy0ut4t.myfritz.net:54241";
      #     persistentKeepalive = 25;
      #   }];
      # };
    };
  };
}
