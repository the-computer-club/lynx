args@{ config, lib, ... }:
with lib;
let
node-options = import ./node-options.nix args;
in {
  options = {
    secretsLookup = mkOption {
      description = ''
        Used as a lookup key for either
          `config ? "sops" && config.sops.secrets ? secretsLookupKey`
          `config ? "age" && config.age.secrets ? secretsLookupKey`

        when deriving the private key for the localhost.

        This value sets the default value for secretsLookupKey the entire network.

        Note: When using agenix, this option shouldn't be set. Instead, configure each peer with
        peers.by-name.nix-spacebar.secretsLookupKey = "filename.age";
      '';

      type = types.nullOr types.str;
      default = null;
    };

    domainName = mkOption {
      type = types.nullOr types.str;
      default = null;
    };

    privateKeyFile = mkOption {
      type = types.nullOr types.str;
      default = null;
    };

    interfaceName = mkOption {
      description = ''
        assign an interface name for the network.
        if none is assigned the network name is used.
      '';

      type = types.nullOr types.str;
      default = null;
    };

    interfaceWriter = mkOption {
        type = types.enum [ "networking.wireguard.interfaces" ];
        default = "networking.wireguard.interfaces";
    };

    hostsWriter = mkOption {
      type = types.enum [ "networking.hosts" ];
      default = "networking.hosts";
    };

    listenPort = mkOption {
      description = '' default port for the network '';
      type = types.nullOr types.port;
      default = 51820;
    };

    # postUp = mkOption {
    #   type = types.nullOr types.str;
    #   default = null;
    # };

    # postDown = mkOption {
    #   type = types.nullOr types.str;
    #   default = null;
    # };

    peers = {
      by-name = mkOption {
        type = types.attrsOf (types.submodule node-options);
        default = {};
      };
    };
  };
}
