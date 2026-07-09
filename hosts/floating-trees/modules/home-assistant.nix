{pkgs, ...}: {
  services.home-assistant = {
    config = {
      "automation ui" = "!include automations.yaml";
      "scene ui" = "!include scenes.yaml";
      "script ui" = "!include scripts.yaml";
      recorder = {};
    };
    extraComponents = [
      "default_config"
      "isal"
    ];
    customComponents = with pkgs.home-assistant-custom-components; [
      tuya_local

      (pkgs.buildHomeAssistantComponent rec {
        owner = "damacus";
        domain = "robovac";
        version = "v2.4.3";

        src = pkgs.fetchFromGitHub {
          inherit owner;
          repo = domain;
          rev = version;
          hash = "sha256-ciuGjaOO8BsvYXQrCjG1Yr3KuWIiySskM0X36Nyl5tU=";
        };
      })
    ];
  };

  services.zigbee2mqtt = {
    enable = true;
    settings = {
      homeassistant.enabled = true;
      permit_join = true;
      serial = {
        port = "/dev/ttyUSB0";
      };
      frontend = {
        enabled = true;
        port = 8091;
        host = "0.0.0.0";
      };
    };
  };

  services.mosquitto.enable = true;
}
