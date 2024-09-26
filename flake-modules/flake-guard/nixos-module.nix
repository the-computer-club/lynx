args@{ config, lib, pkgs, ... }:
with lib;
let
  inherit (import ./lib.nix args)
    toIpv4
    toIpv4Range
    toPeer
    rmParent
    composeNetwork
    safeHead
    deriveSecret
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
    hostName = mkOption {
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

  config.assertions =
   let
     inherit (config.wireguard.build) networks;
     inherit (builtins) filter any attrValues concatStringsSep;
     nets = attrValues networks;
     predicate =
       (net:
         net.self.found
         && net.self.privateKeyFile == null
         && net.self.privateKey == null
       );
   in
  [{
    assertion = !(any predicate nets);
    message =
      ''
        failed to find some of your private key for wireguard.

        ${concatStringsSep "\n"
          ((map (x:
            let
              y = lib.traceValSeqN 3 x;
              safeFormat = x: if x == null then "null" else x;
            in
            ''
            Your host was determined to be: ${y.self.hostName or "null"}
            - config.wireguard.networks.${y.interfaceName}.privateKeyFile => ${safeFormat y.privateKeyFile}
            - config.wireguard.networks.${y.interfaceName}.secretsLookup => ${safeFormat y.secretsLookup}
            - config.wireguard.networks.${y.interfaceName}.privateKey => ${safeFormat y.self.privateKey}
           '')
            (lib.traceValSeqN 3 (filter predicate nets))))
         }
      '';
  }];

  # build network with `self` selected
  config.wireguard.build.networks =
    (mapAttrs (net-name: network:
      let
        _responsible =
          ((mapAttrs (k: x:
            k == cfg.hostName
            || x.hostName == cfg.hostName
          ) network.peers.by-name));

        self-name =
          let
            names =
              builtins.filter(p: p.val) (lib.mapAttrsToList (k: v: {key=k; val=v;}) _responsible);

            name = (safeHead names);
          in
            if (name != null)
            then name.key
            else null;

        peer-data = network.peers.by-name.${self-name};

      in network // {
        inherit _responsible;
        self =
          (mkIf (self-name != null)
            (peer-data //
            ({
              found = lib.mkForce true;
              privateKeyFile =
                safeHead ((filter (x: x == null)
                  (lib.optional (network.privateKeyFile != null) network.privateKeyFile)
                  ++ (deriveSecret network.secretsLookup)
                  ++ (deriveSecret net-name)
                ));
            }))
        );
      }) cfg.build.composed);

  config.networking.firewall.allowedUDPPorts =
    lib.concatLists
      (mapAttrsToList(net-name: network: lib.optionals
        (network.listenPort != null && network.autoConfig.openFirewall)
        [ network.listenPort ]
      ) config.wireguard.build.networks);

  # build the wireguard interfaces via
  config.networking.wireguard.interfaces =
    mapAttrs (net-name: network:
      (mkIf (network.self.found && network.autoConfig."networking.wireguard".interface.enable) {
        inherit (network.self)
          privateKey
          privateKeyFile;

        ips = with network.self; ipv4 ++ ipv6;

        peers = lib.optionals
          network.autoConfig."networking.wireguard".peers.mesh.enable
          (lib.mapAttrsToList (k: v: toPeer v) network.peers.by-name);
      })
    ) cfg.build.networks;

  config.services.rosenpass.settings =
    mapAttrs(net-name: network:
      (mkIf cfg.autoConfig."rosenpass".enable {

        public_key = network.self.publicKey;
        secret_key = network.self.privateKeyFile;
        endpoint = network.self.selfEndpoint;

        settings.peers = lib.optionals
          network.autoConfig."rosenpass.peers".peers.mesh.enable
          (lib.mapAttrsToList (k: v: toRosenPeer v) network.peers.by-name);
      })
    ) config.wireguard.build.networks;

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
                    peer.extraHostNames
                  )
                  ++(lib.optional network.autoConfig."networking.hosts".bareNames.enable peer.hostName)
                  ++(lib.optional network.autoConfig."networking.hosts".FQDNs.enable peer.fqdn)
                  # ++(lib.optionals network.autoConfig."networking.hosts".FQDNs.enable peer.extraFQDNs)
                ;
              }) (peer.ipv4 ++ peer.ipv6)
            )) network.peers.by-name)
        )
      )) cfg.build.networks);
}
