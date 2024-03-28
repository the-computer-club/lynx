{ config, lib, ... }:
with lib;
{
  options.globals = mkOption {
    type = types.attrsOf types.anything;
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
