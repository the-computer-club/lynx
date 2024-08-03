#####
# bring down peer list from flake-guard to nixos
#########
args@{ options, config, lib, pkgs, ... }:
let
  rootConfig = config.wireguard;
  rootOptions = options;

  inherit (import ./lib.nix args)
    toIpv4
    toIpv4Range
    toPeer
    rmParent
  ;

  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    mkRemovedOptionModule
    mkRenamedOptionModule
    mapAttrs'
    nameValuePair
    types
    optionalString
    optionals
  ;
  inherit (builtins)
    mapAttrs
  ;
  node-options = import ./node-options.nix args;
  network-options = import ./network-options.nix args;
in
{
  imports = [
    (mkRemovedOptionModule [ "wireguard" "enable" ] ''
      remove `wireguard.enable` from your flake-parts configuration.

      explaination: wireguard.enable was removed because it often causes user errors
      where `wireguard.enable` was set to `false` but users had enabled
      the nixos options `autoConfig.interface`.
      This lead to errors messages which were hard to understand.
      '')
    ./errors.nix
    ./options.nix
  ];

  flake.nixosModules.flake-guard-host = {config, ...}:
    let cfg = config.flake-guard.networks;
    in
  {
    imports = [
      (import ./nixos-module.nix rootConfig)
    ];

    networking.wireguard.interfaces =
      mapAttrs
      (net-name: network:
        (mkIf (
          network.autoConfig.interface.enable && network.self.found
          && (network.self.interfaceWriter == "networking.wireguard.interfaces"))
          {
            inherit (network.self) listenPort;

            ips = lib.optionals (network.autoConfig.interface.enable)
              (network.self.ipv4 ++ network.self.ipv6);

            privateKeyFile = network.self.privateKeyFile;

            privateKey = network.self.privateKey;

            peers = lib.optionals network.autoConfig.peers.enable
              (lib.mapAttrsToList (k: v: toPeer v) network.peers.by-name);
          }
        )
      ) config.flake-guard.networks;

    networking.hosts =
      rmParent (mapAttrs (network-name: network:
        (mkIf
          (network.autoConfig.hosts.enable && network.self.hostsWriter == "networking.hosts")
          (builtins.foldl' lib.recursiveUpdate {}
            (lib.mapAttrsToList
              (k: peer:
                builtins.foldl' lib.recursiveUpdate {}
                  (map (real-ip:
                    let
                      ip = builtins.head (builtins.split "/" real-ip);
                    in
                      { "${ip}" = [peer.hostname] ++ peer.extraHostnames; })
                    (peer.ipv4 ++ peer.ipv6)
                  )
              )
              network.peers.by-name
            )
          )
        )
      ) config.flake-guard.networks);
  };
}
