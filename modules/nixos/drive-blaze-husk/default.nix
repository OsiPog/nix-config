# Automatically mount encrypted drives at boot: https://blog.pankajraghav.com/2024/09/17/AUTOMOUNT.html
{
  lib,
  config,
  ...
}: let
  inherit (lib) pipe;
  inherit (lib.attrsets) mapAttrs' mapAttrsToList;
  inherit (lib.strings) concatLines;

  drives = {
    blaze = {
      uuid = {
        encrypted = "99a43d3b-75f7-456e-a32d-8f3ef05ffd0a";
        decrypted = "5f05ad57-91e8-4552-9215-b1625c8251f6";
      };
    };
    husk = {
      uuid = {
        encrypted = "a95641a4-b208-4037-9c18-91d8138d2f71";
        decrypted = "6cb04bcd-1879-4112-af51-5853c6fb76fa";
      };
    };
  };
in {
  # Setup the secrets of each host in `drives`
  sops.secrets =
    mapAttrs' (name: _: {
      name = "drives/${name}";
      value = {sopsFile = ./secrets.yaml;};
    })
    drives;

  environment.etc.crypttab.text = pipe drives [
    (mapAttrsToList (name: drive: ''
      ${name} UUID=${drive.uuid.encrypted} ${config.getSopsFile "drives/${name}"}
    ''))
    concatLines
  ];

  fileSystems =
    mapAttrs' (name: drive: {
      name = "/mnt/${name}";
      value = {
        device = "/dev/disk/by-uuid/${drive.uuid.decrypted}";
        fsType = "ext4";
        options = [
          "defaults"
          "noatime"
          "noauto"
          "x-systemd.automount"
          "x-systemd.idle-timeout=3min"
        ];
      };
    })
    drives;
}
