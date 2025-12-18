{ lib }:
with builtins;
let
  inherit (flake-parts-lib) evalFlakeModule;

  this = {
    flake = import ./lib/flake-lib.nix;

    /*
      https://github.com/nix-community/nixago
    */
    nixago = import ./lib/nixago.nix;

    string.stringify = (import ./stringify.nix lib);

    encoding.base64 = import ./lib/encoding/b64decode.nix;

    /*
      extendsInto ::  Attr -> Attr
      extends this lib onto a namespace, much like an overlay
    */
    extendsInto =
      with lib;
      into:
      fix (
        extends
          (final: prev: this)
          (final: into)
      );
  };


  # singleModuleBase = x: {
  #   imports = [
  #     ./flake-modules/builtins/assertions.nix
  #     x
  #   ];
  # };

  # evalAssertions = eval:
  #   let
  #     failedAssertions = map (x: x.message) (filter (x: !x.assertion) eval.config.assertions);
  #     warnings = eval.config.warnings;
  #   in
  #     if (failedAssertions != [])
  #     then
  #       builtins.abort (concatStringsSep "\n\n" failedAssertions)
  #     else
  #       if (warnings != [])
  #       then
  #         builtins.trace (concatStringsSep "\n\n" warnings)
  #           eval
  #       else eval;


  # evalFlakeModuleWithAssertions = a: m:
  #   evalAssertions (evalFlakeModule a (singleModuleBase m));
in
  this
