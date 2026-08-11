{
  pkgs,
  config,
  ...
}: {
  services.librechat.env.SEARXNG_INSTANCE_URL = "http://localhost:${toString config.services.searx.settings.port}";

  # web searcher
  services.searx = {
    enable = true;
    package = pkgs.searxng;
    settings.port = 1235;
  };

  # crawler
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };
  systemd.services.firecrawl = {
    description = "crawler for websites to give llm md output";
    script = ''
      
      docker compose up
    '';
    serviceConfig = { User = "firecrawl"; Group = "firecrawl"; };
  };
}
