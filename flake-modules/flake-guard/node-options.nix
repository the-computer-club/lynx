args@{config, lib, ...}:
with lib;
let
  autoconfig-options = import ./autoconfig-options.nix;
in
{
  options = {
    interfaceName = mkOption {
      type = types.nullOr types.str;
      default = null;
    };

    ipv6 = mkOption {
      type = types.listOf types.str;
      default = [];
    };

    ipv4 = mkOption {
      type = types.listOf types.str;
      default = [];
    };

    publicKey = mkOption {
      type = types.nullOr types.str;
      default = null;
    };

    privateKeyFile = mkOption {
      type = types.nullOr types.str;
      default = null;
    };

    privateKey = mkOption {
      description = ''
        world wide web readable credentials
      '';

      type = types.nullOr (types.either types.str types.path);
      default = null;
    };

    ignoreHostname = mkEnableOption
      "do not include this hostname in your /etc/hosts";

    autoConfig = mkOption {
      type = types.submodule autoconfig-options;
      default = {};
    };

    hostName = mkOption {
      description = ''
        This data is used to correlate peer information with the correct nixos-machine.
        If both this option, and `wireguard.networks.<<network>>.lookupKey` match values.
        This peer configuration will be applied to that machine's interface.

        If this option is not set. This parent's key will be used instead.
      '';

      type = types.nullOr types.str;
      default = null;
    };

    extraHostNames = mkOption {
      type = types.listOf types.str;
      default = [];
    };

    secretsLookup = mkOption {
      description = ''
      This value represents the key used in `sops.secret.<secretsLookup>` in the evaluation of the nixos module.
      This key is used to lookup the private key for the wireguard connection.
      '';
      type = types.nullOr types.str;
      default = null;
    };

    listenPort = mkOption {
      type = types.nullOr types.int;
      default = null;
    };

    selfEndpoint = mkOption {
      type = types.nullOr types.str;
      default = null;
    };

    fqdn = mkOption {
      type = types.nullOr types.str;
      default = null;
    };

    extraFQDNs = mkOption {
      type = with types; listOf nonEmptyStr;
      default = [];
    };

    nameAsFQDN = mkEnableOption "use hostname as a fully qualified domain name. ignoring `domainName` ";

    persistentKeepalive = mkOption {
      type = types.nullOr types.int;
      default = null;
    };

    groups = mkOption {
      type = types.listOf types.str;
      default = [];
    };

    domainName = mkOption {
      type = types.nullOr types.str;
      default = null;
    };

    build =
      let
        mod = {
          options = {
            address = mkOption {
              type = types.str;
            };
            mask = mkOption {
              type = types.str;
            };
          };
        };

        peerBuilt = types.submodule mod;
      in
    {
      ipv4 = mkOption {
        type = types.listOf peerBuilt ;
        default = [];
      };

      ipv6 = mkOption {
        type = types.listOf peerBuilt;
        default = [];
      };

      first.ipv4 = mkOption {
        type = types.nullOr peerBuilt;
        default = null;
      };

      first.ipv6 = mkOption {
        type = types.nullOr peerBuilt;
        default = null;
      };
    };
  };
}
