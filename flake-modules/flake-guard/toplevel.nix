args@{ config, lib, ... }:
with lib;
let
  network-options = import ./network-options.nix args;
  autoconfig-options = import ./autoconfig-options.nix args;

  inherit (import ./lib.nix args)
    composeNetwork;
in
{
  options = {
    # sops.enable = mkEnableOption ''
    #   enable looking up secrets via `sops.secrets ? <lookup>`.
    #   enabling this without sops will not cause errors, and instead skip the check

    #   reads from `sops.secrets.<secretsLookup>` to store the privateKeyFile option in `networking.wireguard.interfaces.<network>.privateKeyFile`.
    #   The option `secretsLookup` look is derived from either
    #   - `<network>.self.secretsLookup`
    #   - `<network>.secretsLookup`

    #   if the option `secretsLookup` has not been set, it will be defaulted to the network's interface name.
    #   The network interface's default name is the value of wireguard.networks.<key> where key describes the current network,
    #   and network interface name.
    # '';

    # age.enable = mkEnableOption
    # ''
    #   reads from `age.secrets.<secretsLookup>` to store the privateKeyFile option in `networking.wireguard.interfaces.<network>.privateKeyFile`.
    #   The option `secretsLookup` look is derived from `<network>.self.secretsLookup`
    # '';

    defaults.autoConfig = mkOption {
      type = (types.submodule autoconfig-options);
      default = {};
    };

    networks = mkOption {
      default = {};
      description = ''describes a wireguard network. '';
      type = types.attrsOf (types.submodule network-options);
    };

    build.networks = mkOption {
      description = ''
        this is composed from the options defined in wireguard.networks; including assigned defaults.
        this option exists for the flake-parts scope which expect a composed network at the flake level.
        Other wise in the nixos context, one is provided in the nixos-module.nix
        under `wireguard.build._stubbed`
      '';
      type = types.attrsOf (types.submodule network-options);
      default = {};
    };
  };
}
