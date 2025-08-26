{
  pkgs,
  vosk-model ? (
    pkgs.fetchzip {
      # Go to https://alphacephei.com/vosk/models to find the download links
      url = "https://alphacephei.com/vosk/models/vosk-model-en-us-0.22-lgraph.zip";
      # url = "https://alphacephei.com/vosk/models/vosk-model-de-0.21.zip";
      # hash = "sha256-Pqf6Eo15aIfI3NYN1kYakUVyA6JD0hR2rW+R/2hDug4="; # vosk-model-de-0.21
      # hash = "sha256-kakOhA7hEtDM6WY3oAnb8xKZil9WTA3xePpLIxr2+yM="; # vosk-model-en-us-0.22
      hash = "sha256-GVheflRwix9PnQjIVFl1mkNRduaYRNvZGhTZaobTibY="; # vosk-model-en-us-0.22-lgraph
      # hash = pkgs.lib.fakeHash;
    }
  ),
  ...
}:
pkgs.python3Packages.buildPythonApplication {
  pname = "nerd-dictation";
  version = "0.1.0"; # Using a placeholder version as we're fetching from main branch

  src = pkgs.fetchFromGitHub {
    owner = "ideasman42";
    repo = "nerd-dictation";
    rev = "main";
    sha256 = "sha256-M/05SUAe2Fq5I40xuWZ/lTn1+mNLr4Or6o0yKfylVk8=";
  };

  format = "other"; # This is a script, not a standard Python package

  nativeBuildInputs = [ pkgs.makeWrapper ];

  propagatedBuildInputs =
    with pkgs.python3Packages;
    [
      numpy
    ]
    ++ [
      (pkgs.callPackage ./vosk.nix pkgs) # add the local needed package
    ];
  #
  installPhase = ''
    mkdir -p $out/bin
    install -m755 nerd-dictation $out/bin/nerd-dictation

    # Create a wrapper script that conditionally adds the --vosk-model-dir flag
    mv $out/bin/nerd-dictation $out/bin/.nerd-dictation-unwrapped

    cat > $out/bin/nerd-dictation << EOF
    #!/bin/sh
    if [ "\$1" = "begin" ]; then
      exec $out/bin/.nerd-dictation-unwrapped "\$@" --vosk-model-dir ${vosk-model}
    else
      exec $out/bin/.nerd-dictation-unwrapped "\$@"
    fi
    EOF

    chmod +x $out/bin/nerd-dictation

    wrapProgram $out/bin/.nerd-dictation-unwrapped \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.pulseaudio ]}
  '';
  meta = with pkgs.lib; {
    description = "Simple hackable offline speech to text using VOSK-API";
    homepage = "https://github.com/ideasman42/nerd-dictation";
    license = licenses.gpl3;
    platforms = platforms.linux;
    maintainers = with maintainers; [ ];
    mainProgram = "nerd-dictation";
  };
}
