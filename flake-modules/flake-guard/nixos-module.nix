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
    deriveSecretWith
  ;

  deriveSecret = deriveSecretWith config;

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
    length
    split
  ;

  network-options = import ./network-options.nix args;
  toplevel-options = import ./toplevel.nix args;
  cfg = config.wireguard;
in
{
  imports = [
    (mkRenamedOptionModule
      [ "networking" "wireguard" "networks" ]
      [ "wireguard" "networks" ]
    )
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

  config.wireguard.build.composed = mkIf config.wireguard.enable
    (composeNetwork config.wireguard.networks);

  # build network with `self` selected
  config.wireguard.build.networks =
    (mapAttrs (net-name: network:
      let
        _responsible =
          pipe network.peers.by-name [
            (filterAttrs  (k: x: k == cfg.hostName || x.hostName == cfg.hostName))
            attrNames
          ];

        self' =
          if ((length _responsible) == 1)
          then network.peers.by-name."${head _responsible}"
          else null;
      in
        network // {
          inherit _responsible;
          self = mkIf (self' != null)
            (self' // {
                found = mkForce true;
                privateKeyFile =
                  safeHead ((filter (x: x == null)
                    (optional (network.privateKeyFile != null) network.privateKeyFile)
                    ++ optional (network.secretsLookup != null) (deriveSecret network.secretsLookup)
                    ++ (deriveSecret net-name)
                  ));
            });
        }) cfg.build.composed);

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
          (map (y:
            let
              safeFormat = x: if x == null then "null" else x;
            in
            ''
            Your host was determined to be: ${y.self.hostName or "null"}
            - config.wireguard.networks.${y.interfaceName}.privateKeyFile => ${safeFormat y.privateKeyFile}
            - config.wireguard.networks.${y.interfaceName}.secretsLookup => ${safeFormat y.secretsLookup}
              - [sops.secrets."${y.secretsLookup}".path => "${config.sops.secrets."${y.secretsLookup}".path}"]
              - [age.secrets."${y.secretsLookup}".path => "${config.age.secrets."${y.secretsLookup}".path}"]
            - config.wireguard.networks.${y.interfaceName}.privateKey => ${safeFormat y.self.privateKey}
           '')
            (filter predicate nets))
         }
      '';
  }];

  config.networking.firewall.allowedUDPPorts =
    concatLists
      (mapAttrsToList(net-name: network: optionals
        (network.listenPort != null && network.autoConfig.openFirewall)
        [ network.listenPort ]
      ) config.wireguard.build.networks);

  # build the wireguard interfaces via
  config.networking.wireguard.interfaces =
    mapAttrs (net-name: network:
      (mkIf (network.self.found && network.autoConfig."networking.wireguard".interface.enable) {
        inherit (network)
          listenPort;

        inherit (network.self)
          privateKey
          privateKeyFile;

        ips = with network.self; ipv4 ++ ipv6;

        peers = lib.optionals
          network.autoConfig."networking.wireguard".peers.mesh.enable
          (mapAttrsToList (k: v: toPeer v) network.peers.by-name);
      })
    ) cfg.build.networks;

  #config.systemd.services."${(network: peer: peerUnitServiceName network.interfaceName (peerUnitName peer.publicKey)}"

  config.services.rosenpass.settings =
    mapAttrs(net-name: network:
      (mkIf cfg.autoConfig."rosenpass".enable {
        public_key = network.self.publicKey;
        secret_key = network.self.privateKeyFile;
        endpoint = network.self.selfEndpoint;

        settings.peers = lib.optionals
          network.autoConfig."rosenpass.peers".peers.mesh.enable
          (mapAttrsToList (k: v: toRosenPeer v) network.peers.by-name);
      })
    ) config.wireguard.build.networks;

  # build the hostnames via
  config.networking.hosts =
    rmParent (mapAttrs (network-name: network:
      (mkIf
        network.autoConfig."networking.hosts".enable
        (foldl' recursiveUpdate {}
          (mapAttrsToList (k: peer: foldl' recursiveUpdate {}
            (map (real-ip:
              let
                ip = head (split "/" real-ip);
              in
              optionalAttrs (!peer.ignoreHostname) {
                "${ip}" =
                  (optionals
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
