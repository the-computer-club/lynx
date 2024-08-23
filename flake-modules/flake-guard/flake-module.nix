args@{ options, config, lib, pkgs, ... }:
let
inherit (lib)
  mkOption
  mkEnableOption
  mkIf
  mkMerge
  mkRenamedOptionModule
  types
  mapAttrs
  mapAttrs'
  attrValues'
  attrNames
  partition
  nameValuePair
  mapAttrsToList
  recursiveUpdate
  ;

inherit (import ./lib.nix)
  toPeers;

node-options = import ./node-options.nix args;
network-options = import ./network-options.nix args;

in
{
  config.flake.nixosModules = {
    flake-guard-host = ./nixos-module.nix;

    flake-guard-host-fp = {
      flake-guard.flake-parts.enable = true;
      flake-guard.flake-parts.passthru = config.wireguard.build.networks;
    };
  };

  options.wireguard = {
    secretsLookup.sops.enable = mkEnableOption ''
      enable looking up secrets via `sops.secrets ? <lookup>`.
      enabling this without age will not cause errors, and instead skip the check
      '';

    secretsLookup.age.enable = mkEnableOption ''
      enable looking up secrets via `age.secrets ? <lookup>`.
      enabling this without age will not cause errors, and instead skip the check
      '';

    defaults.interfaceWriter = mkOption {
      type = types.str;
      default = "networking.wireguard.interfaces";
    };

    defaults.hostsWriter = mkOption {
      type = types.str;
      default = "networking.hosts";
    };

    networks = mkOption {
      type = types.attrsOf (types.submodule network-options);
      default = {};
    };

    build.networks = mkOption {
      default = {};
      type = types.attrsOf (types.submodule network-options);
    };

    _loader-stub = mkOption {
      type = types.functionTo (types.attrsOf
        (types.submodule network-options)
      );

      default = (import ./stub.nix) lib;
    };
  };

  config.wireguard.build.networks =
    config.wireguard._loader-stub
      config.wireguard.networks;
}
