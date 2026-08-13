builtins.warn "FIXME: makemkv is currently broken" ({pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # stable.makemkv
  ];

  # for makemkv
  boot.kernelModules = ["sg"];
})
