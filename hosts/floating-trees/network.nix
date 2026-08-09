# This is a special nix module. It is imported into `networking.hosts.<name>` of every nixos configuration.
# So that each host can see the network configuration of all other hosts.
{
  config,
  lib,
  ...
}: let
  inherit (config.lib) require servicesById allServiceIds;
in {
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
    # all backup paths of all enabled services
    require =
      (require "backup-paths" allServiceIds)
      # extra require
      // {
        backup-paths.zombie-horse-drive = {
          host = "floating-trees";
          path = "/mnt/zombie-horse/cloud";
        };
      };
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

    provide.ports.http.proxy.domain = "auth.axelhax.net";

    require =
      (require "ldap-servers" ["lldap"])
      // (require "mail-servers" ["snm"])
      // (require "oidc-clients" [
        "headscale"
        "opencloud"
        "vikunja"
        "actual"
        "librechat"
        "mealie"
        "paperless"
      ]);
  };

  # --- LLDAP
  services.lldap = {
    enable = true;
    provide.ports = {
      ldaps.proxy = {
        domain = "ldap.axelhax.net";
        hidden = true;
      };
      http.proxy = {
        domain = "users.axelhax.net";
        hidden = true;
      };
    };
    require = require "ldap-clients" [
      "snm"
      "authelia"
      "opencloud"
      "jellyfin"
      "home-assistant"
    ];
  };

  # --- NGINX HTTP
  services.staticWebsites = {
    enable = true;
    sites = ["axelhax" "transit-vis"];
    provide.ports = {
      "http-axelhax".proxy.domain = "axelhax.net";
      "http-transit-vis".proxy.domain = "transit-vis.axelhax.net";
    };
  };

  # --- OPENCLOUD
  services.opencloud = {
    enable = true;
    provide.ports.http.proxy.domain = "cloud.axelhax.net";

    require =
      (require "ldap-servers" ["lldap"])
      // (require "oidc-servers" ["authelia"]);
  };

  # --- JELLYFIN
  services.jellyfin = {
    enable = true;
    provide.ports.http.proxy.domain = "media.axelhax.net";
    require = require "ldap-servers" ["lldap"];
  };

  # --- HOME ASSISTANT
  services.home-assistant = {
    enable = true;
    provide.ports.http.proxy = {
      domain = "home.axelhax.net";
      hidden = true;
    };
    require = require "ldap-servers" ["lldap"];
  };

  # --- VIKUNJA
  services.vikunja = {
    enable = true;
    provide.ports.http.proxy.domain = "tasks.axelhax.net";
    require =
      (require "oidc-servers" ["authelia"])
      // (require "mail-servers" ["snm"]);
  };
  # --- ACTUAL
  services.actual = {
    enable = true;
    provide.ports.http.proxy = {
      domain = "budget.axelhax.net";
      hidden = true;
    };
    require = require "oidc-servers" ["authelia"];
  };

  # --- MEALIE
  services.mealie = {
    enable = true;
    provide.ports.http.proxy.domain = "kochen.axelhax.net";
    require = require "oidc-servers" ["authelia"];
  };

  # --- PAPERLESS
  services.paperless = {
    enable = true;
    provide.ports.http.proxy.domain = "papier.axelhax.net";
    require = require "oidc-servers" ["authelia"];
  };

  # --- LLM CHAT
  services.librechat = {
    enable = true;
    provide.ports.http.proxy.domain = "ai.axelhax.net";
    require =
      (require "openai-apis" ["llamacpp"])
      // (require "oidc-servers" ["authelia"]);
  };
}
