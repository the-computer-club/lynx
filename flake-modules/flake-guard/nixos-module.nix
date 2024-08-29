args@{ options, config, lib, pkgs, ... }:
with lib;
let
  inherit (import ./lib.nix args)
    toIpv4
    toIpv4Range
    toPeer
    rmParent
    composeNetwork
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
    head
    filters
    foldl'
  ;
  network-options = import ./network-options.nix args;
  node-options = import ./node-options.nix args;

  settings-options = import ./settings.nix args;
  autoconfig-options = import ./autoconfig-options.nix args;
  toplevel-options = import ./toplevel.nix args;
  cfg = config.wireguard;
in
{
  imports = [
    (mkRenamedOptionModule
      [ "networking" "wireguard" "networks" ]
      [ "wireguard" "networks" ])

    (mkRenamedOptionModule
      [ "flake-guard" "networks" ]
      [ "wireguard" "networks" ])
  ];

  options.wireguard = recursiveUpdate toplevel-options.options {
      enable = mkEnableOption "enable wireguard nixos module";
      hostname = mkOption {
        description = ''
          configures `wireguard.networks.<network>.self`
          from  `wireguard.networks.<network>.peers.by-name.<hostname>`

          This option is responsible for pairing this current configuration with the peer in the network.
          The hostname should be equal to an attribute key inside of `<network>.peers.by-name`
          '';
        type = types.str;
        default = config.networking.hostName;
      };

      build.composed = mkOption {
        description =
          ''
          first stage of manipulating the input data. This data has all the defaults filled in,
          and user preferences applied, but has not defined `self`.
          '';

        type = types.attrsOf (types.submodule network-options);
        default = {};
      };
  };

  config.wireguard.build.composed =
    (composeNetwork config.wireguard.networks);

  # build network with `self` selected
  config.wireguard.build.networks = mkIf cfg.enable
    (mapAttrs (net-name: network:
      let
        _responsible =
          ((mapAttrs (k: x:
            k == cfg.hostname
            || x.hostname == cfg.hostname
          ) network.peers.by-name));

        self-name =
          let
            names =
              builtins.filter(p: p.val) (lib.mapAttrsToList (k: v: {key=k; val=v;}) _responsible);
          in
            if (builtins.length names) == 1
            then (builtins.head names).key
            else null;

        peer-data = network.peers.by-name.${self-name};

        network-defaults = {
          inherit (network) listenPort; #sops age;
        };

      in network // {
        inherit _responsible;
        self = (mkIf (self-name != null)
          ((peer-data // network-defaults) //
           {
             found = lib.mkForce true;
             privateKeyFile =
               let
                 deriveSecret = lookup:
                   map (backend:
                     if (config ? backend && config.${backend}.secrets ? lookup) then
                       config.${backend}.secrets.${lookup}
                     else null
                   ) ["sops" "age"];
               in
                 head (filter (x: x == null)
                   (map (x: if (x != null) then x else null) [
                     peer-data.privateKeyFile
                     network.privateKeyFile
                     (deriveSecret peer-data.secretsLookup)
                     (deriveSecret network.secretsLookup)
                   ])
                 );
           }));
      }) cfg.build.composed);

  # build the wireguard interfaces via
  config.networking.wireguard.interfaces =
    mapAttrs (net-name: network:
      (mkIf (network.self.found && network.autoConfig."networking.wireguard".interface.enable) {
        inherit (network.self)
          listenPort
          privateKey
          privateKeyFile;

        ips = with network.self; ipv4 ++ ipv6;

        peers = lib.optionals
          network.autoConfig."networking.wireguard".peers.mesh.enable
          (lib.mapAttrsToList (k: v: toPeer v) network.peers.by-name);
      })
    ) cfg.build.networks;

  # build the hostnames via
  config.networking.hosts =
    rmParent (mapAttrs (network-name: network:
      (mkIf
        network.autoConfig."networking.hosts".enable
        (builtins.foldl' lib.recursiveUpdate {}
          (lib.mapAttrsToList (k: peer: builtins.foldl' lib.recursiveUpdate {}
            (map (real-ip:
              let
                ip = builtins.head (builtins.split "/" real-ip);
              in
              lib.optionalAttrs (!peer.ignoreHostname) {
                "${ip}" =
                  (lib.optionals
                    network.autoConfig."networking.hosts".names.enable
                    ([peer.hostname] ++ peer.extraHostnames)
                  ) ++
                  (lib.optional
                    network.autoConfig."networking.hosts".FQDNs.enable
                    ([peer.fqdn] ++ peer.extraFQDNs)
                  );
              }) (peer.ipv4 ++ peer.ipv6)
            )) network.peers.by-name)
        )
      )) cfg.build.networks);
}
