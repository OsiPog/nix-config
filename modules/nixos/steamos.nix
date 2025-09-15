{inputs, ...}: {
  imports = [
    inputs.jovian-nixos.nixosModules.default
  ];

  nixpkgs.config.allowUnfree = true;

  jovian = {
    steam = {
      enable = true;
      user = "steam";
    };
  };
  services.greetd = {
    enable = true;
    settings = {
      # Run steamos on boot (autologin)
      initial_session = {
        command = "start-gamescope-session";
        user = "steam";
      };
    };
  };
}
