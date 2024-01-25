{ config, lib, pkgs, ... }:
with lib;
{
  options.globals = mkOption {
    type = lib.types.attrsOf lib.types.any;
    default = {};
    description = ''
      A set of global variables to be made available to all modules.
    '';
    example = literalExpression {
      value = ''
        globals.var-name = ["value"];
      '';
    };
  };
}
