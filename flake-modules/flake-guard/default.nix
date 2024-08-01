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
    toPeer;

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

    ./options.nix
  ];

  flake.nixosModules.flake-guard-host = {config, ...}:
    let cfg = config.flake-guard.networks;
    in
  {
    imports = [
      (mkRenamedOptionModule
        [ "networking" "wireguard" "networks" ]
        [ "flake-guard" "networks" ])
    ];

    options.flake-guard = {
      enable = mkEnableOption "enable flake-guard nixos module";

      hostname = mkOption {
        type = types.str;
        default = config.networking.hostname;
      };

      networks = mkOption {
        default = {};
        type = types.attrsOf (types.submodule {
          options = {
            autoConfig = {
              interface.enable = mkEnableOption "automatically generate the underlying network interface";
              interface.writer = mkOption {
                type = types.enumOf [ "networking.wireguard.interfaces" ];
                default = "networking.wireguard.interfaces";
              };

              peers.enable = mkEnableOption "automatically generate the peers -- this will add all peers in the network to the interface.";
              hosts.enable = mkEnableOption "automatically generate `etc.hostnames` enteries for each peer";
              hosts.writer = mkOption {
                type = types.enumOf [ "networking.hosts" ];
                default = "networking.hosts";
              };
            };

            interfaceName = mkOption {
              type = types.nullOr types.str;
              default = null;
            };

            peers = {
              by-name = mkOption {
                type = types.attrsOf types.attrs;
                default = {};
              };

              by-group = mkOption {
                type = types.attrsOf types.attrs;
                default = {};
              };
            };

            _responsible = mkOption {
              type = types.listOf types.attrs;
              default = [];
            };

            self = mkOption {
              type = types.submodule (import ./node-options.nix);
              default = {};
            };
          };
        });
      };
    };

    config = mkIf config.flake-guard.enable {
      flake-guard.networks =
        (mapAttrs (net-name: network:
          let
            _responsible =
              (mapAttrs (k: x:
                   k == config.flake-guard.hostname
                || x.hostname == config.flake-guard.hostname
                || k == network.self.hostname
                || x.hostname == network.self.hostname
              ) network.peers.by-name);

            self-name =
                let
                  size = (builtins.attrNames _responsible);
                in
                  if (builtins.length size) == 1
                  then builtins.head size
                  else null;

            peer-data = network.peers.by-name.${self-name};
          in
          {
            inherit _responsible;
            self = peer-data //
              {
                peers =
                  (builtins.foldl' (s: group-name:
                    lib.recursiveUpdate s network.peers.group-by.${group-name})
                    {} peer-data.groups
                  );

                privateKeyFile =
                  let
                    deriveSecret = lookup:
                      map (backend:
                        lib.optionalString (config ? backend && config.${backend}.secrets ? lookup)
                          config.${backend}.secrets.${lookup}
                      ) ["sops" "age"];
                  in
                    lib.optionalString (self-name != null)
                      (builtins.head (builtins.filter (x: x == null)
                        (map (x: lib.optionalString (x != null) x)
                        [
                          peer-data.privateKeyFile
                          network.privateKeyFile
                          (deriveSecret peer-data.secretsLookup)
                          (deriveSecret network.privateKeyFile)
                        ]))
                      );
              };
          }) rootConfig.build.networks);

      networking.wireguard.interfaces = mapAttrs'
        (net-name: network:
        nameValuePair
          network.interfaceName
          (mkIf network.autoConfig.interface
          && (network.self.interfaceWriter == "networking.wireguard.interfaces")
          {
            inherit (network.self) listenPort;

            ips = lib.optionals (network.autoConfig.interface.enable)
              (network.self.ipv4 ++ network.self.ipv6);

            privateKeyFile = lib.optionals (network.autoConfig.interface.enable)
                network.self.privateKeyFile;

            peers = lib.optionals network.autoConfig.peers.enable
              (lib.mapAttrsToList (k: v: toPeer v) network.self.peers);
          })
        ) rootConfig.build.networks;

      networking.hosts =
        lib.mapAttrs' (network-name: network:
          let
            ranges = map (p: toIpv4Range p.ipv4 ++ p.ipv6) network.peers.list;
            parted = builtins.filter (rng: (
              if rng.cidr == "32" then true
              else builtins.trace
                "[flake-guard] WARNING: will not generate host names for cidr ranges other than /32"
                false
            )) ranges;

            ips = map (rng: rng.ip) ranges;

            hosts-output = lib.mapAttrs'(net-name: net:
              let
                names = map (p: (lib.optionals (p.hostname != null) [p.hostname]++p.flake-guard.extraHostnames)) ;
              in
                map (ip: (lib.nameValuePair ip names)) ips
            ) network.peers.by-group;
          in
            (mkIf
              (network.autoConfig.hosts.enable && network.self.hostsWriter == "networking.hosts")
              hosts-output
            )
        ) rootConfig.build.networks;
    };
  };
}
