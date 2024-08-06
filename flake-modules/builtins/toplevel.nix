{ config, options, lib, ... }:
with lib;
{
  options.flake._config = mkOption {
    type = types.raw;
    default = config;
    internal = true;
  };

  options.flake._options = mkOption {
    type = types.raw;
    default = options;
    internal = true;
  };
}
