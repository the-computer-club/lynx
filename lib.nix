{ flake-parts-lib, ... }:
with builtins;
let
  inherit (flake-parts-lib) evalFlakeModule;

  singleModuleBase = x: {
    imports = [
      ./flake-modules/builtins/assertions.nix
      x
    ];
  };

  evalAssertions = eval:
    let
      failedAssertions = map (x: x.message) (filter (x: !x.assertion) eval.config.assertions);
      warnings = eval.config.warnings;
    in
      if (failedAssertions != [])
      then
        builtins.abort (concatStringsSep "\n\n" failedAssertions)
      else
        if (warnings != [])
        then
          builtins.trace (concatStringsSep "\n\n" warnings)
            eval
        else eval;


  evalFlakeModuleWithAssertions = a: m:
    evalAssertions (evalFlakeModule a (singleModuleBase m));
in
{
  inherit evalFlakeModuleWithAssertions;
  mkFlakeWithAssertions = args: module:
    let
      eval = evalFlakeModuleWithAssertions args module;
    in
      eval.config.flake;
}
