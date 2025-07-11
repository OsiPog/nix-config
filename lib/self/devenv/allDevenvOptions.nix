self: let
  pkgs = import self.inputs.nixpkgs {};

  inherit (builtins) getEnv hasAttr readFile replaceStrings toFile pathExists typeOf attrNames match head concatStringsSep;
  inherit (pkgs) runCommand copyPathToStore;
  inherit (pkgs.lib) pipe;

  # Helper function to convert a deep set with only strings to a valid string expression
  # (Why does something like this not exist in nixpkgs?)
  stringSetToString = set:
    pipe set [
      # Get attribute names
      attrNames
      # collapse to string
      (map (
        name:
          "${name}="
          + (
            if (typeOf set.${name} == "set")
            then stringSetToString set.${name}
            else "\"${set.${name}}\""
          )
          + ";"
      ))
      # concat
      (concatStringsSep "")
      # add braces
      (str: "{${str}}")
    ];

  # all options provided by devenv
  devenvOptions = let
    devenvFlake = self.inputs.devenv;
    pkgs = import devenvFlake.inputs.nixpkgs {};
  in
    # This is copied and adapted from:
    # https://github.com/cachix/devenv/blob/3febc91939aea65bdff8850f026443afb6b6b22f/flake.nix#L95
    (pkgs.lib.evalModules {
      modules = [
        (devenvFlake.outPath + "/src/modules/top-level.nix")
      ];
      specialArgs = {
        inherit pkgs;
        inputs = devenvFlake.inputs;
      };
    }).options;

  # The options specific for the currently openend devenv project
  projectOptions =
    pipe (
      (getEnv "PWD") + "/.devenv.flake.nix"
    ) [
      # The .devenv.flake.nix file has a special format. It allows complex logic inside the inputs block
      # which normal flakes do not allow. So we evaluate the inputs and then convert it to a string now with
      # baked in let values.
      # The outputs expression must stay the same. So the part where the outputs begin is just kept.
      (file: ''
        { inputs = ${stringSetToString (import file).inputs};
        ${pipe file [readFile (match ".*(outputs.*$)") head]}
      '')

      # A little hack that includes the `project` variable that contains the options set.
      # the variable is defined in a let..in block in the outputs section.
      (replaceStrings ["devShell ="] ["inherit project;devShell ="])

      # put this file together with devenv.nix and devenv.lock (as flake.lock)
      (expr:
        runCommand "devenv-flake" {} ''
          mkdir -p $out
          cp ${copyPathToStore ((getEnv "PWD") + "/devenv.nix")} $out/devenv.nix
          cp ${copyPathToStore ((getEnv "PWD") + "/devenv.lock")} $out/flake.lock
          cp ${toFile "flake.nix" expr} $out/flake.nix;
          echo "builtins.getFlake \"$out\"" > $out/default.nix # needed for the import statement
        '')

      # once again, import the final flake, this time actually as a flake
      import

      # lastly, we can extract the options from the outputs
      (finalFlake: finalFlake.outputs.project.options)
    ];
in
  # only include general devenv options when devenv is in inputs of provided flake
  (
    if hasAttr "devenv" self.inputs
    then devenvOptions
    else {}
  )
  //
  # only include project options if we actually are in a devenv project
  (
    if pathExists ((getEnv "PWD") + "/.devenv.flake.nix")
    then projectOptions
    else {}
  )
