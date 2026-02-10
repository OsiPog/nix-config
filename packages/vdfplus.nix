{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
}:
buildNpmPackage {
  pname = "vdfplus";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "RoyalBingBong";
    repo = "vdfplus";
    rev = "b7bb2885a673099db8aeaf5d69f66889059cf293";
    hash = "sha256-tO64IFd347hYPGvO9ExMfgZ747ay9kWr7EQzaLRjN8M=";
  };

  npmDepsHash = "sha256-KD6EhU2LowfMkoLtwWin6h4Gj2Vd37JAClCSNBUJQ7k=";

  meta = with lib; {
    description = "A small library that aims to help with converting Valve's KeyValue (VDF) format to JSON and vice versa";
    homepage = "https://github.com/RoyalBingBong/vdfplus";
    license = licenses.isc;
    maintainers = [];
    platforms = platforms.all;
  };
}
