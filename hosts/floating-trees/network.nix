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

  # NOTE: orphan bare port (no owning service); parked until the home proxy returns.
  # services.<svc>.provide.ports.vmu = { port = 8080; proxy.domain = "vmu.axelhax.net"; };

  # --- REVERSE PROXY
  # services.reverseProxy = {
  #   id = "home-proxy";
  #   enable = true;
  #   ignoreHidden = true;
  #   ipAddress = "10.12.21.41";
  # };
  # --- DNSMASQ, directly connect devices to server on home network without outside traffic
  # services.dnsmasq = {
  #   id = "home-dns";
  #   enable = true;
  #   require.dns-overrides = servicesById.home-proxy.provide.dns-overrides;
  # };

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
      "librechat"
      "mealie"
      "paperless"
    ];
  };
  services.authelia.provide.ports.authelia.proxy.domain = "auth.axelhax.net";

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
  services.lldap.provide.ports = {
    ldaps.proxy = {
      domain = "ldap.axelhax.net";
      hidden = true;
    };
    lldap.proxy = {
      domain = "users.axelhax.net";
      hidden = true;
    };
  };

  # --- NGINX HTTP
  services.staticWebsites = {
    enable = true;
    sites = ["axelhax" "transit-vis"];
  };
  services.staticWebsites.provide.ports = {
    "staticWebsites-axelhax".proxy.domain = "axelhax.net";
    "staticWebsites-transit-vis".proxy.domain = "transit-vis.axelhax.net";
  };

  # --- OPENCLOUD
  services.opencloud = {
    enable = true;
    require.ldap-server = servicesById.lldap.provide.ldap-server;
    require.oidc-server = servicesById.authelia.provide.oidc-server;
  };
  services.opencloud.provide.ports.opencloud.proxy.domain = "cloud.axelhax.net";

  # --- JELLYFIN
  services.jellyfin = {
    enable = true;
    require.ldap-server = servicesById.lldap.provide.ldap-server;
  };
  services.jellyfin.provide.ports.jellyfin.proxy.domain = "media.axelhax.net";

  # --- HOME ASSISTANT
  services.home-assistant = {
    enable = true;
    require.ldap-server = servicesById.lldap.provide.ldap-server;
  };

  services.home-assistant.provide.ports.home-assistant.proxy = {
    domain = "home.axelhax.net";
    hidden = true;
  };

  # --- VIKUNJA
  services.vikunja = {
    enable = true;
    require.oidc-server = servicesById.authelia.provide.oidc-server;
    require.mail-server = servicesById.snm.provide.mail-server;
  };
  services.vikunja.provide.ports.vikunja.proxy.domain = "tasks.axelhax.net";
  # --- ACTUAL
  services.actual = {
    enable = true;
    require.oidc-server = servicesById.authelia.provide.oidc-server;
  };
  services.actual.provide.ports.actual.proxy = {
    domain = "budget.axelhax.net";
    hidden = true;
  };

  # --- MEALIE
  services.mealie = {
    enable = true;
    require.oidc-server = servicesById.authelia.provide.oidc-server;
  };
  services.mealie.provide.ports.mealie.proxy.domain = "kochen.axelhax.net";

  # --- PAPERLESS
  services.paperless = {
    enable = true;
    require.oidc-server = servicesById.authelia.provide.oidc-server;
  };
  services.paperless.provide.ports.paperless.proxy.domain = "papier.axelhax.net";

  # --- LLM CHAT
  services.librechat = {
    enable = true;
    require.openai-api = servicesById.llamacpp.provide.openai-api;
    require.oidc-server = servicesById.authelia.provide.oidc-server;
  };
  services.librechat.provide.ports.librechat.proxy.domain = "ai.axelhax.net";
}
