{ config, lib, pkgs, ... }:
with lib;
{
  options.globals = mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
    description = ''
      A set of global variables to be made available to all modules.
    '';
    example = literalExpression
      ''
        globals.var-name = ["value"];
    '';
  };
}
