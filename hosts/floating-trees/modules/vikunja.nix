{
  lib,
  config,
  ...
}: {
  # fixes database is busy
  sops.secrets."vikunja/db-pass" = {
    sopsFile = ../secrets.yaml;
    group = "vikunja";
    mode = "0440";
  };
  users = {
    users.vikunja = {
      isSystemUser = true;
      group = "vikunja";
    };
    groups.vikunja = {};
  };
  systemd.services.vikunja.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "vikunja";
  };
  services.vikunja = {
    settings.database.password.file = config.getSopsFile "vikunja/db-pass";
    database = rec {
      type = "postgres";
      user = "vikunja";
      database = user; # needs to be the same so that ensureDBOwnership below works
    };
  };
  services.postgresql = {
    enable = true;
    ensureDatabases = [config.services.vikunja.database.database];
    ensureUsers = [
      {
        name = config.services.vikunja.database.user;
        ensureDBOwnership = true;
        ensureClauses.password = "SCRAM-SHA-256$4096:y6QFOVdSbgvq/+/iK+J7Kw==$PcNgEaWRG/9y7BVHJvmvnXSU4q6x//qfcU/lE13t+dU=:nYSEBF0AxlBVcL7/hWmLb3KuyIrAG03pNY71HyR41i0=";
      }
    ];
  };
}
