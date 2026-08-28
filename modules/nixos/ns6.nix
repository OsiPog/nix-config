# Numark NS6 DJ controller.
#
# The NS6 exposes only vendor-specific USB interfaces: no USB-Audio and no
# USB-MIDI descriptors, so no kernel driver binds it and it has no ALSA
# presence at all. Support comes from `ns6`, a userspace driver that speaks the
# device's Ploytec protocol over libusb and publishes an ALSA sequencer MIDI
# port that Mixxx connects to.
#
# Source and protocol notes live in the `ns6` flake input.
{
  inputs,
  lib,
  pkgs,
  ...
}: let
  ns6 = inputs.ns6.packages.${pkgs.stdenv.hostPlatform.system}.ns6;
in {
  # `ns6 learn` and `ns6 probe` are worth having on PATH for mapping work.
  environment.systemPackages = [ns6];

  # Without `uaccess` the usbfs node reverts to root ownership on every replug,
  # since nothing in the kernel claims the device. Granting it to the seat means
  # the driver can also just be run by hand from a terminal.
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="15e4", ATTRS{idProduct}=="0079", TAG+="uaccess", GROUP="wheel", MODE="0660", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ns6.service"
  '';

  systemd.services.ns6 = {
    description = "Numark NS6 userspace MIDI driver";
    # Started by the udev rule above when the controller appears on the bus. The
    # NS6 has its own power switch, so that happens independently of the cable.
    serviceConfig = {
      ExecStart = lib.getExe ns6;
      # The driver waits a little for the device and then exits if it never
      # shows up; a few retries covers a slow enumeration without spinning
      # forever while the controller is switched off.
      Restart = "on-failure";
      RestartSec = 3;
      # Needs raw usbfs and the ALSA sequencer, and nothing else.
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = ["AF_UNIX" "AF_NETLINK"];
    };
    startLimitIntervalSec = 60;
    startLimitBurst = 5;
  };
}
