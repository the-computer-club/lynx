args@{ self, inputs, options, config, lib, ... }:
let
  inherit (lib)
    mkOption
    mkEnableOption
    types
  ;

  inherit (import ./lib.nix args)
    composeNetwork
  ;

  toplevel-options = (import ./toplevel.nix args);
  inherit (inputs.lynx.nixosModules) flake-guard-host;
in
{
  config.flake.nixosModules.flake-guard-host = {
    imports = [ flake-guard-host ];
    wireguard = config.wireguard;
  };

  options.wireguard = mkOption {
    type = (types.submodule toplevel-options);
    default = {};
  };

  config.wireguard.build.networks =
    (composeNetwork config.wireguard.networks);
}
