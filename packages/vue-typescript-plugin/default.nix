{pkgs, ...}:
pkgs.buildNpmPackage rec {
  pname = "vue-typescript-plugin";
  version = "3.0.4";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@vue/typescript-plugin/-/typescript-plugin-${version}.tgz";
    hash = "sha256-4dI6Cujka7Kqvy4K+1czr9xo+sbiCv4Aa2/SrMseqqs=";
  };

  npmDepsHash = "sha256-53TxkzZVH6TjbvbCkK/IsVeX0N4ScP2YnICk9HHSbxQ=";
  dontNpmBuild = true;

  postPatch = ''
    ln -s ${./package-lock.json} package-lock.json
  '';

  meta = with pkgs.lib; {
    description = "TypeScript plugin for Vue";
    homepage = "https://github.com/vuejs/language-tools";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.all;
  };
}
