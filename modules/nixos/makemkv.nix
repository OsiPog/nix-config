{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    makemkv
  ];

  # for makemkv
  boot.kernelModules = ["sg"];
}
