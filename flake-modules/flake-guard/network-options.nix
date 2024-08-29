args@{ config, lib, ... }:
with lib;
let
node-options = import ./node-options.nix args;
autoconfig-options = import ./autoconfig-options.nix args;
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

    listenPort = mkOption {
      description = '' default port for the network '';
      type = types.nullOr types.port;
      default = 51820;
    };

    _responsible = mkOption {
      type = types.attrsOf types.bool;
      default = {};
    };

    self = mkOption {
      type = types.submodule {
        options =
          ({ found = mkEnableOption "self was found"; } // node-options.options);
      };
      default = {};
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

      by-group = mkOption {
        type = types.attrsOf (types.attrsOf (types.submodule node-options));
        default = {};
      };
    };

    autoConfig = mkOption {
      type = (types.submodule autoconfig-options);
      default = {};
    };

    metadata.acmeServer = mkOption {
      type = types.nullOr types.nonEmptyStr;
      default = null;
    };
  };
}
