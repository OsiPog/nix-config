{
  description = "Osi's NixOS Config Flake";

  inputs = {
    # --- Core Foundation
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/release-25.05";
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    robotnix.url = "github:nix-community/robotnix"; # build aosp with nix

    # --- Flake Libraries
    blueprint = {
      # url = "github:numtide/blueprint";
      url = "github:osipog/blueprint/feat/allow-nixpkgs-package-definitions";
      # url = "/home/osi/repositories/github.com/osipog/blueprint.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- NixOS Modules
    # Private modules
    nix-config-private = {
      url = "git+ssh://git@github.com/osipog/nix-config-private.git?ref=main&shallow=1";
      inputs.blueprint.follows = "blueprint";
    };
    # Declarative dotfiles
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Declarative disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Automatic hardware configuration
    nixos-facter-modules.url = "github:nix-community/nixos-facter-modules";
    # Applies a theme to all programs
    stylix = {
      url = "github:nix-community/stylix";
      # url = "github:osipog/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Declare secrets
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Declarative neovim distribution
    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Better udev nix interface
    custom-udev-rules.url = "github:MalteT/custom-udev-rules";
    # Fix for command not found
    flake-programs-sqlite = {
      url = "github:wamserma/flake-programs-sqlite";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # NixOS on the steam deck
    jovian-nixos = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    simple-nixos-mailserver = {
      url = "git+https://gitlab.com/simple-nixos-mailserver/nixos-mailserver.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Better Minecraft Server support
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- Packages
    # Development environments the easy nix way
    devenv.url = "github:cachix/devenv";
    # Repo containing vscode extensions from marketplace and open vsx
    nix-vscode-extensions = {
      # url = "github:nix-community/nix-vscode-extensions";
      url = "github:dseum/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Repo containing firefox addons
    nix-firefox-addons = {
      url = "github:OsiPog/nix-firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Scripts to login into eduroam networks (university wifi)
    eduroam = {
      # url = "github:MayNiklas/eduroam-flake";
      url = "github:Kiyotoko/eduroam-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # wayland idle inhibitor
    matcha = {
      url = "git+https://codeberg.org/QuincePie/matcha";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Utility to switch tabs in kitty terminal
    kitty-tab-switcher = {
      url = "github:OsiPog/kitty-tab-switcher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Customized build of libfprint to make my laptops fingerprint reader work
    libfprint = {
      url = "github:osipog/libfprint";
      inputs.blueprint.follows = "blueprint";
    };
  };

  outputs = inputs: inputs.blueprint {inherit inputs;};
}
