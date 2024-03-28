{ config, lib, ... }:
with lib;
{
  options.globals = mkOption {
<<<<<<< HEAD
    type = lib.types.attrsOf lib.types.anything;
=======
    type = types.attrsOf types.anything;
>>>>>>> devel
    default = {};
    description = ''
      A set of global variables to be made available to all modules.
    '';
    example = literalExpression
      ''
<<<<<<< HEAD
        globals.var-name = ["value"];
    '';
=======
      globals.var-name = ["value"];
      '';
>>>>>>> devel
  };
}
