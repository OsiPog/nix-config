{
  description = "Osi's NixOS Config Flake";

  inputs = {
    # --- Core Foundation
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/release-24.11";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- System
    # Declarative disk partitioning
    disko.url = "github:nix-community/disko";
    # Hardware detection and configuration
    nixos-facter-modules.url = "github:nix-community/nixos-facter-modules";
    # Secret management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # personal information repository
    nix-config-private.url = "git+ssh://git@github.com/osipog/nix-config-private.git?ref=main&shallow=1";
    # Stylix, theming made easy peasy
    stylix = {
      url = "github:nix-community/stylix";
      # url = "github:osipog/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- Development
    # Development environments the easy nix way
    devenv.url = "github:cachix/devenv";

    # --- Applications
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
    # Declarative neovim distribution
    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- System Utilities
    # Better udev nix interface
    custom-udev-rules.url = "github:MalteT/custom-udev-rules";
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

    # --- Hardware-Specific
    # Customized build of libfprint to make my laptops fingerprint reader work
    libfprint-goodix-55b4.url = "github:oscar-schwarz/libfprint-goodix-55b4";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    inherit (builtins) attrNames attrValues;
    inherit (nixpkgs) lib;
    inherit (lib) genAttrs;

    inherit (self.lib) importFilesAsAttrs flattenAttrs;

    modulesIn = path: flattenAttrs (importFilesAsAttrs path);
    pkgsForAllSystems = lambda: genAttrs (attrNames nixpkgs.legacyPackages) (system: lambda nixpkgs.legacyPackages.${system});
  in rec {
    nixosConfigurations = import ./hosts self;

    lib = import ./lib self;

    homeManagerModules = modulesIn ./modules/hm;
    nixosModules = modulesIn ./modules/nixos;

    packages = pkgsForAllSystems (pkgs: lib.${pkgs.system}.callPackagesInDirectoryToAttrs ./pkgs);
    formatter = pkgsForAllSystems (pkgs: pkgs.alejandra);
    devShells = pkgsForAllSystems (pkgs: {
      default = pkgs.mkShell {
        name = (import ./flake.nix).description; # sir, is that legal?
        buildInputs = attrValues packages.${pkgs.system};
      };
    });
  };
}
