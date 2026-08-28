# Numark NS6 DJ controller.
#
# The NS6 exposes only vendor-specific USB interfaces: no USB-Audio and no
# USB-MIDI descriptors, so no kernel driver binds it and it has no ALSA
# presence at all. Support comes from `ns6`, a userspace driver that speaks the
# device's Ploytec protocol over libusb and publishes an ALSA sequencer MIDI
# port that Mixxx connects to.
#
# The package, the udev rule and the service all come from the ns6 flake; this
# just turns them on.
{inputs, ...}: {
  imports = [inputs.ns6.nixosModules.default];

  services.ns6.enable = true;
}
