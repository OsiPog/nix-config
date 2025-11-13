{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  unzip,
  vscodium,
  vscode-extensions,
}:
buildNpmPackage rec {
  pname = "vscode-langservers-extracted";
  version = "4.8.0";

  srcs = [
    (fetchFromGitHub {
      owner = "hrsh7th";
      repo = "vscode-langservers-extracted";
      rev = "v${version}";
      hash = "sha256-sGnxmEQ0J74zNbhRpsgF/cYoXwn4jh9yBVjk6UiUdK0=";
    })
    vscodium.src
  ];

  sourceRoot = "source";

  npmDepsHash = "sha256-LFWC87Ahvjf2moijayFze1Jk0TmTc7rOUd/s489PHro=";

  nativeBuildInputs = [unzip];

  buildPhase = let
    extensions =
      if stdenv.hostPlatform.isDarwin
      then "../VSCodium.app/Contents/Resources/app/extensions"
      else "../resources/app/extensions";
  in ''
    npx babel ${extensions}/css-language-features/server/dist/node \
      --out-dir lib/css-language-server/node/
    npx babel ${extensions}/html-language-features/server/dist/node \
      --out-dir lib/html-language-server/node/
    npx babel ${extensions}/json-language-features/server/dist/node \
      --out-dir lib/json-language-server/node/
    cp -r ${vscode-extensions.dbaeumer.vscode-eslint}/share/vscode/extensions/dbaeumer.vscode-eslint/server/out \
      lib/eslint-language-server
  '';

  meta = with lib; {
    description = "HTML/CSS/JSON/ESLint language servers extracted from vscode";
    homepage = "https://github.com/hrsh7th/vscode-langservers-extracted";
    license = licenses.mit;
    maintainers = with maintainers; [lord-valen];
  };
}
