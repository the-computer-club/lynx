#####
# bring down peer list from flake-guard to nixos
#########
args@{ config, lib, pkgs, ... }:
let
  rootConfig = config.wireguard;
  inherit (import ./lib.nix args)
    toPeer;

  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    types
    optionalString
    optionals
  ;
  inherit (builtins)
    mapAttrs
  ;
in
{
  imports = [ ./options.nix  ];

  flake.nixosModules.flake-guard-host = {config, ...}:
    let cfg = config.networking.wireguard.networks;
    in
  {
    options.networking.wireguard.networks = mkOption {
      default = {};
      type = types.attrsOf (types.submodule {
        options = {

          autoConfig = {
            interface = mkEnableOption "automatically generate the underlying network interface";
            peers = mkEnableOption "automatically generate the peers -- this will add all peers in the network to the interface.";
          };

          peers = {
            by-name = mkOption {
              type = types.attrsOf types.attrs;
              default = {};
            };

            list = mkOption {
              type = types.listOf types.attrs;
              default = [];
            };
          };

          self = {
            listenPort = mkOption {
              type = types.port;
            };

            ips = mkOption {
              type = types.listOf types.str;
            };

            privateKeyFile = mkOption {
              type = types.str;
            };
          };
        };
      });
    };

    config = mkIf rootConfig.enable
    {

      networking.wireguard.networks = mapAttrs (net-name: network:
        let

          self-name = builtins.head
                  (builtins.filter (x: x == config.networking.hostName)
                    (builtins.attrNames network.peers.by-name));

          peer-data = network.peers.by-name.${self-name};

          listenPort = if peer-data.listenPort != null
                      then peer-data.listenPort
                      else network.listenPort;

          self = {
                inherit listenPort;
                privateKeyFile =
                  let
                    secondarySops = rootConfig.build.networks.${net-name}.peers.by-name.${self-name}.sopsLookup;
                    lookup = if peer-data.sopsLookup != null
                            then peer-data.sopsLookup
                            else secondarySops;

                  in
                    if peer-data.privateKeyFile != null
                    then peer-data.privateKeyFile
                    else (
                      if (lookup != null && config ? "sops" && config.sops.secrets ? "${lookup}" ) then
                        config.sops.secrets.${lookup}.path
                      else if (lookup != null && config ? "age" && config.age.sops.secrets ? "${lookup}" ) then
                        config.age.secrets.${lookup}.path
                      else null
                    );
                ips = with peer-data; ipv4 ++ ipv6;
          };

        in
        {
          inherit self;
          peers.by-name = mapAttrs (pname: peer: (toPeer peer)) network.peers.by-name;
          peers.list = map toPeer (builtins.attrValues network.peers.by-name);
        }) rootConfig.networks;

      networking.wireguard.interfaces = mapAttrs (net-name: network:
        mkIf network.autoConfig.interface {
          inherit (config.networking.wireguard.networks.${net-name}.self)
            listenPort
            privateKeyFile
            ips;

          peers = optionals network.autoConfig.peers
            (builtins.attrValues
              config.networking.wireguard.networks.${net-name}.peers.by-name
            );
        })
        config.networking.wireguard.networks;
    };
  };
}
