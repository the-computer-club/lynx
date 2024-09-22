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

    nameAsFQDN = mkEnableOption "use hostname as a fully qualified domain name. ignoring `domainName` ";

    domainName = mkOption {
      description = ''
      simply appends {hostName}.{domainName}, so that hosts which perfer
      names can utilize `peer.fqdn`
      '';

      type = types.nullOr types.str;
      default = null;
    };

    authority = {
      rootCertificate = mkOption {
        description = ''
          ACME root certificate.
        '';
        type = types.nullOr types.path;
        default = null;
      };

      subca = mkOption {
        default = {};
        description = ''
        sub-ca information for clients.
        '';

        type = types.attrsOf (types.submodule {
          option.certificate = mkOption {
            default = null;
            type = types.nullOr types.path;
          };

          option.endpoint = mkOption {
            default = null;
            type = types.nullOr types.path;
          };
        });
      };

      dns = mkOption {
        type = types.nullOr (types.listOf types.nonEmptyStr);
        default = null;
      };
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

    metadata = mkOption {
      type = types.unspecified;
      default = null;
    };
  };
}
