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
      (mkRenamedOptionModule
        [ "networking" "wireguard" "networks" ]
        [ "flake-guard" "networks" ])
    ];

    options.flake-guard = {
      enable = mkEnableOption "enable flake-guard nixos module";

      hostname = mkOption {
        type = types.str;
        default = config.networking.hostName;
      };

      networks = mkOption {
        default = {};
        type = types.attrsOf (types.submodule {
          options = network-options.options // {
            autoConfig = {
              interface.enable = mkEnableOption "automatically generate the underlying network interface";
              peers.enable = mkEnableOption "automatically generate the peers -- this will add all peers in the network to the interface.";
              hosts.enable = mkEnableOption "automatically generate `etc.hostnames` enteries for each peer";
            };

            interfaceName = mkOption {
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

            peers = {
              by-name = mkOption {
                type = types.attrsOf (types.submodule node-options);
                default = {};
              };

              by-group = mkOption {
                type = types.unspecified;
                #type = types.attrsOf types.attrOf node-options;
                default = {};
              };
            };

            _responsible = mkOption {
              type = types.attrsOf types.bool;
              default = [];
            };

            self = mkOption {
              type = types.attrsOf types.unspecified;
              default = {};
            };
          };
        });
      };
    };

    config = mkIf config.flake-guard.enable {
      flake-guard.networks =
        mapAttrs (net-name: network:
          let
            _responsible =
              (mapAttrs (k: x:
                 k == config.flake-guard.hostname
                || x.hostname == config.flake-guard.hostname
              ) network.peers.by-name);

            self-name =
                let
                  names =
                    builtins.filter(p: p.val)
                    (lib.mapAttrsToList (k: v: {key=k; val=v;}) _responsible);
                in
                  if (builtins.length names) == 1
                  then (builtins.head names).key
                  else null;

            peer-data = network.peers.by-name.${self-name};

            network-defaults = {
              inherit (network) listenPort hostsWriter interfaceWriter;
            };

          in
          network // {
            inherit _responsible;

            self = (mkIf (self-name != null)
              ((peer-data // network-defaults) //
              {
                found = true;
                # peers =
                #   (builtins.foldl' (s: group-name:
                #     lib.recursiveUpdate s network.peers.group-by.${group-name})
                #     {} peer-data.groups
                #   );

                privateKeyFile =
                  let
                    deriveSecret = lookup:
                      map (backend:
                        if (config ? backend && config.${backend}.secrets ? lookup) then
                          config.${backend}.secrets.${lookup}
                        else null
                      ) ["sops" "age"];
                  in
                    if (self-name != null) then
                      (builtins.head (builtins.filter (x: x == null)
                        (map (x: if (x != null) then x else null)
                        [
                          peer-data.privateKeyFile
                          network.privateKeyFile
                          (deriveSecret peer-data.secretsLookup)
                          (deriveSecret network.privateKeyFile)
                        ]))
                      )
                    else null;
              }));
            }) rootConfig.build.networks;

      networking.wireguard.interfaces =
        mapAttrs
        (net-name: network:
          (mkIf (network.autoConfig.interface.enable && network.self.found
                 && (network.self.interfaceWriter == "networking.wireguard.interfaces"))
            {
              inherit (network.self) listenPort;

              ips = lib.optionals (network.autoConfig.interface.enable)
                (network.self.ipv4 ++ network.self.ipv6);

              privateKeyFile = network.self.privateKeyFile;

              privateKey = network.self.privateKey;

              peers = lib.optionals network.autoConfig.peers.enable
                (lib.mapAttrsToList (k: v: toPeer v) network.peers.by-name);
          })
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
  };
}
