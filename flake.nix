{
  description = "Osi's NixOS Config Flake";

  inputs = {
    # --- Core Foundation
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/release-24.11";

    # --- Flake Libraries
    blueprint = {
      url = "github:numtide/blueprint";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- NixOS Modules
    # Private modules
    nix-config-private.url = "git+ssh://git@github.com/osipog/nix-config-private.git?ref=main&shallow=1";
    # Declarative dotfiles
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Declarative disk partitioning
    disko.url = "github:nix-community/disko";
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

    # --- Packages
    # Development environments the easy nix way
    devenv.url = "github:cachix/devenv";
    # Repo containing vscode extensions from marketplace and open vsx
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Repo containing firefox addons
    nix-firefox-addons = {
      url = "github:OsiPog/nix-firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Scripts to login into eduroam networks (university wifi)
    eduroam = {
      url = "github:MayNiklas/eduroam-flake";
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
    libfprint-goodix-55b4.url = "github:oscar-schwarz/libfprint-goodix-55b4";
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;

      inherit (lib) pipe;
      inherit (lib.attrsets) attrsToList listToAttrs;

      outputs = inputs.blueprint { inherit inputs; };
    in
    outputs
    // {
      nixosConfigurations =
        outputs.nixosConfigurations
        // (pipe outputs.nixosConfigurations [
          attrsToList
          (map (
            {
              name,
              value,
            }:
            {
              name = name + "-without-secrets";
              value = value.extendModules {
                modules = [
                  {
                    sops.secrets = lib.mkForce { };
                  }
                ];
              };
            }
          ))
          listToAttrs
        ]);
    };
}
