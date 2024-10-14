{ lib, ... }:
with lib;
{
  options.certificate = mkOption {
    default = null;
    type = types.nullOr types.path;
  };

  options.endpoint = mkOption {
    default = null;
    type = types.nullOr types.nonEmptyStr;
  };
}
