# This is a special nix module. It is imported into `networking.hosts.<name>` of every nixos configuration.
# So that each host can see the network configuration of all other hosts.
{
  servicesById,
  lib,
  ...
}: {
  domain = "axelhax.net"; # on my home router this domain resolves here
  vpn.ip = "100.64.0.4";
  ssh = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDYdr33vJvtTnrSDiEhCUkc0fL7GyrZG9UEL8zjaKJpU root@floating-trees";
    allowConnectionsFrom = ["dead-voxel" "biome-fest"];
  };

  ports.vmu = {
    port = 8080;
    reverseProxy.domain = "vmu.axelhax.net";
  };

  # --- REVERSE PROXY
  services.reverseProxy = {
    id = "home-proxy";
    enable = true;
    ignoreHidden = true;
    ipAddress = "10.12.21.41";
  };
  # --- DNSMASQ, directly connect devices to server on home network without outside traffic
  services.dnsmasq = {
    id = "home-dns";
    enable = true;
    require.dns-overrides = servicesById.home-proxy.provide.dns-overrides;
  };

  # --- RESTIC
  services.backup = {
    enable = true;
    repoPath = "/mnt/mob-farm";
    mirrorPath = "/mnt/zombie-horse/mirror";
    # all backup paths
    require.backup-paths =
      lib.flatten (lib.mapAttrsToList (_: service: service.provide.backup-paths) servicesById)
      ++ [
        {
          host = "floating-trees";
          path = "/mnt/zombie-horse/cloud";
        }
      ];
  };

  # --- MINECRAFT
  # services.minecraft-server.enable = true;
  # ports.minecraft-java.reverseProxy.domain = "axelhax.net";
  # ports.minecraft-bedrock.reverseProxy.domain = "axelhax.net";

  # --- HYTALE
  # services.hytale-server.enable = true;
  # ports.hytale.reverseProxy.domain = "axelhax.net";

  # --- AUTHELIA
  services.authelia = {
    enable = true;
    require.ldap-server = servicesById.lldap.provide.ldap-server;
    require.mail-server = servicesById.snm.provide.mail-server;
    require.oidc-clients = builtins.foldl' (acc: e: acc ++ servicesById.${e}.provide.oidc-clients) [] [
      "headscale"
      "opencloud"
      "vikunja"
      "actual"
    ];
  };
  ports.authelia.reverseProxy.domain = "auth.axelhax.net";

  # --- LLDAP
  services.lldap = {
    enable = true;
    require.ldap-clients = builtins.foldl' (acc: e: acc ++ servicesById.${e}.provide.ldap-clients) [] [
      "snm"
      "authelia"
      "opencloud"
      "jellyfin"
      "home-assistant"
    ];
  };
  ports.ldaps.reverseProxy = {
    domain = "ldap.axelhax.net";
    hidden = true;
  };
  ports.lldap.reverseProxy = {
    domain = "users.axelhax.net";
    hidden = true;
  };

  # --- NGINX HTTP
  services.staticWebsites = {
    enable = true;
    sites = ["axelhax" "transit-vis"];
  };
  ports.staticWebsites-axelhax.reverseProxy.domain = "axelhax.net";
  ports.staticWebsites-transit-vis.reverseProxy.domain = "transit-vis.axelhax.net";

  # --- OPENCLOUD
  services.opencloud = {
    enable = true;
    require.ldap-server = servicesById.lldap.provide.ldap-server;
    require.oidc-server = servicesById.authelia.provide.oidc-server;
  };
  ports.opencloud.reverseProxy.domain = "cloud.axelhax.net";

  # --- JELLYFIN
  services.jellyfin = {
    enable = true;
    require.ldap-server = servicesById.lldap.provide.ldap-server;
  };
  ports.jellyfin.reverseProxy.domain = "media.axelhax.net";

  # --- HOME ASSISTANT
  services.home-assistant = {
    enable = true;
    require.ldap-server = servicesById.lldap.provide.ldap-server;
  };

  ports.home-assistant.reverseProxy = {
    domain = "home.axelhax.net";
    hidden = true;
  };

  # --- VIKUNJA
  services.vikunja = {
    enable = true;
    require.oidc-server = servicesById.authelia.provide.oidc-server;
    require.mail-server = servicesById.snm.provide.mail-server;
  };
  ports.vikunja.reverseProxy.domain = "tasks.axelhax.net";
  # --- ACTUAL
  services.actual = {
    enable = true;
    require.oidc-server = servicesById.authelia.provide.oidc-server;
  };
  ports.actual.reverseProxy = {
    domain = "budget.axelhax.net";
    hidden = true;
  };
}
