{ options, config, lib, pkgs, ... }:
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

node-options = import ./node-options.nix;

in
{
  # imports = [
  #   (mkRenamedOptionModule
  #     ["wireguard" "networks" "" "sopsLookup"]
  #     ["wireguard" "networks" "" "secretsLookup"])
  # ];

  options.wireguard = {
    secretsLookup.sops.enable = mkEnableOption ''
      enable looking up secrets via `sops.secrets ? <lookup>`.
      enabling this without age will not cause errors, and instead skip the check
      '';

    secretsLookup.age.enable = mkEnableOption ''
      enable looking up secrets via `age.secrets ? <lookup>`.
      enabling this without age will not cause errors, and instead skip the check
      '';

    default.interfaceWriter = mkOption {
      type = types.str;
      default = "networking.wireguard.interfaces";
    };

    default.hostsWriter = mkOption {
      type = types.str;
      default = "networking.hosts";
    };

    networks = mkOption {
      type = types.attrsOf (types.submodule {
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

          interfaceName = mkOption {
            description = ''
              assign an interface name for the network.
              if none is assigned the network name is used.
            '';

            type = types.nullOr types.str;
            default = null;
          };

          interfaceWriter = mkOption {
            type = types.str;
            default = config.wireguard.defaults.interfaceWriter;
          };

          hostsWriter = mkOption {
            type = types.str;
            default = config.wireguard.default.hostsWriter;
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
              type = types.attrsOf (types.submodule options.submodule.flake-guard.peer);
              default = {};
            };
          };
        };
      });
    };

    build.networks = mkOption {
      type = types.attrsOf (types.submodule ({
        options = node-options.options // {
          peers.by-group = mkOption {
            type = types.attrsOf types.attrsOf (types.submodule node-options);
            default = {};
          };
        } ;
      }));
    };
  };

  config.wireguard.build.networks =
    (mapAttrs (net-name: network:
      rec {
        interfaceName = net-name;
        peers.by-name = mapAttrs (peer-name: peer:
          let
            mkGuardOpt = name:
              if (peer.${name} != null)
              then peer.${name}
              else network.${name};

            groups = ["all"] ++ peer.groups;
          in

          peer // {
            inherit groups;
            keyLookup = peer-name;
            hostWriter = mkGuardOpt "hostWriter";
            interfaceWriter = mkGuardOpt "interfaceWriter";
            secretslookup = mkGuardOpt "secretsLookup";
            listenPort = mkGuardOpt "listenPort";
            privateKeyFile = mkGuardOpt "privateKeyFile";
          }
        ) network.peers.by-name;

        peers.by-group =
        let
          all-groups = lib.concatLists mapAttrsToList(k: v: v.groups) peers.by-name;
          per-groups = lib.genAttrs all-groups
            (group-name: lib.partition (p:
              builtins.elem group-name p.groups
            ) peers.by-name
          ).right;
          per-groups-attrs = mapAttrs (group: peers: builtins.foldl' (s: x:
            s // { ${x.keyLookup} = x; }
          ) {} peers);
        in
          per-groups-attrs;
      }) config.wireguard.networks);
}
