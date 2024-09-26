{ config, lib, pkgs, ... }:
let
  body.options = with lib; {
    assertion = mkOption {
      type = types.bool;
      default = false;
    };
    message = mkOption {
      type = types.nullOr types.str;
      default = null;
    };
  };
in
{
  options.evalChecks = with lib; {
    assertions =
      mkOption {
        type = types.listOf (types.submodule body);
        default = [];
      };

    failed = mkOption {
      type = types.listOf (types.submodule body);
      default = [];
    };
  };

  config.evalChecks.failed =
      builtins.filter
        (x: x.assertion == false)
        config.evalChecks.assertions;

  # config.perSystem = {pkgs, ...}:
  #   {
  #     packages.evalCheck = pkgs.runCommandLocal "evalCheck.sh" ''
  #     ${config.packages.unit-testkit}/bin/unit-test.py <<EOF
  #       ${builtins.toJSON config.flake.evalChecks.failed}
  #     EOF
  #     '';

  #     packages.unit-testkit = pkgs.python312Packages.callPackage (
  #       {buildPythonApplication, anytree, fire}:
  #         buildPythonApplication {
  #           pname = "unit-testkit";
  #           version = "0.0.1";
  #           propagatedBuildInputs = [ anytree fire ];
  #           src = lib.cleanSource ./.;
  #         }
  #     );
  #   };

 }
