{config, lib, ...}:
with lib;
{
  options = {
    fqdns = mkOption {
      type = types.listOf types.str;
      default = [];
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

    hostname = mkOption {
      description = ''
        This data is used to correlate peer information with the correct nixos-machine.
        If both this option, and `flake-guard.networks.<<network>>.lookupKey` match values.
        This peer configuration will be applied to that machine's interface.

        If this option is not set. This parent's key will be used instead.
      '';

      type = types.nullOr types.str;
      default = null;
    };

    extraHostnames = mkOption {
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

    interfaceWriter = mkOption {
        type = types.enum [ "networking.wireguard.interfaces" ];
        default = "networking.wireguard.interfaces";
    };

    hostsWriter = mkOption {
      type = types.enum [ "networking.hosts" ];
      default = "networking.hosts";
    };

    persistentKeepalive = mkOption {
      type = types.nullOr types.int;
      default = null;
    };

    groups = mkOption {
      type = types.listOf types.str;
      default = [];
    };
  };
}