{ options, config, lib, pkgs, ... }:
let
inherit (lib)
  mkOption
  mkEnableOption
  mkIf
  mkMerge
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

  node =  {
    # only use /32 & /128 respectively
    # as wireguard is point-to-point over layer 3+udp
    options = {
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
        type = types.nullOr types.unspecified;
        default = null;
      };

      sopsLookup = mkOption {
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

      persistentKeepalive= mkOption {
        type = types.nullOr types.int;
        default = null;
      };

      # module = mkOption {
      #   type = types.nullOr types.unspecified;
      #   default = null;
      # };

      # peerlist = mkOption {
      #   type = types.listOf (types.submodule options.networking.wireguard.interfaces.XXX.peers);
      #   default = [];
      # };
    };
  };
in
{
  options.wireguard = {
    enable = mkEnableOption "Enable wireguard";

    networks = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          # shape = mkOption {
          #   type = types.enum [ "star" "proxychain" "mesh" "nobody" ];
          #   default = "mesh";
          # };

          sopsLookup = mkOption {
            type = types.nullOr types.str;
            default = null;
          };

          listenPort = mkOption {
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
              type = types.attrsOf (types.submodule node);
              default = {};
            };
          };
        };
      });
    };

    build.networks = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          network-name = mkOption {
            type = types.nullOr types.str;
            default = {};
          };

          peers.by-name = mkOption {
            type = types.attrsOf (types.submodule node);
            default = {};
          };
        };
      });
    };
  };

  config.wireguard.build.networks =
    mapAttrs (net-name: network:
    {
      peers.by-name = mapAttrs (peer-name: peer:
        peer // {
          sopsLookup = if peer.sopsLookup != null
                       then peer.sopsLookup
                       else network.sopsLookup;
        }
      ) network.peers.by-name;
    }) config.wireguard.networks;
}
