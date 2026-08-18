{pkgs, ...}: {
  environment.systemPackages = with pkgs;
    builtins.warn "FIXME: makemkv is currently broken" [
      # stable.makemkv
    ];

  # for makemkv
  boot.kernelModules = ["sg"];
}
