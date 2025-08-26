{ pkgs, ... }:
pkgs.python3Packages.buildPythonPackage rec {
  pname = "vosk";
  version = "0.3.45";

  format = "wheel";

  src = pkgs.fetchurl {
    url = "https://github.com/alphacep/vosk-api/releases/download/v0.3.45/vosk-0.3.45-py3-none-linux_x86_64.whl";
    hash = "sha256-WR/EVcvr7d7SGjlF5buZXtKj7g+cRKgAVYutipjYoUI=";
  };

  nativeBuildInputs = with pkgs; [
    pkg-config
    autoPatchelfHook
  ];

  buildInputs = [
    pkgs.ffmpeg
    pkgs.stdenv.cc.cc.lib
  ];

  propagatedBuildInputs = with pkgs.python3Packages; [
    numpy
    cffi
    srt
    requests
    tqdm
  ];

  # The package doesn't have tests
  doCheck = false;

  pythonImportsCheck = ["vosk"];

  meta = with pkgs.lib; {
    description = "Offline speech recognition API for Python, with PyPy support";
    homepage = "https://alphacephei.com/vosk/";
    license = licenses.asl20;
    maintainers = [];
    platforms = platforms.all;
  };
}
