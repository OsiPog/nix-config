# Shared Modules

This directory contains all Nix modules that can be shared among all configurations. The first level of subdirectories defines what kind of Nix module is stored in it:

- `modules/hm` - Home Manager modules
- `modules/nixos` - NixOS modules
- `modules/nixos-user` - Nix functions that take a username and return a NixOS module. Useful when certain user configurations are not possible in Home Manager

The single modules in the respective module directories can be organized arbitrarily. Though to keep a certain reproducability and ability to easily share a Nix file with others you may follow certain guidelines:

- Do not heavily rely on module options that are not present in upstream NixOS or Home Manager
- If you do rely on such custom options import the necessary modules from the flake using the `imports` attribute.
- Do not assume a certain option is already set by another module
  - But there can be exceptions (though it should be obvious where the dependencies lie), for example `modules/hm/hyprland/touch.nix` obviously depends on Hyprland being enabled by `modules/hm/hyprland/default.nix`