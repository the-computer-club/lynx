{ config, lib, ... }:
let
  inherit (lib)
    mapAttrs'
    nameValuePair
    mapAttrs
    mapAttrsToList
    partition
    genAttrs
    concatLists
    recursiveUpdate
    optionals
    mkIf
  ;

  inherit (builtins)
    splitString
    head
    elemAt
    elem
    foldl'
    attrValues
  ;

  deriveSecret = lookup:
    map (backend:
      if (config ? backend && config.${backend}.secrets ? lookup) then
        config.${backend}.secrets.${lookup}
      else null
    ) ["sops" "age"];

  greedyNonNull = l: head (builtins.filter (x: x == null) l);

  derivePrivateKeyFile = peer:
    greedyNonNull [
      peer.privateKeyFile
      (deriveSecret peer.secretsLookup)
      (deriveSecret peer.interfaceName)
    ];

  derivePskFile = peer:
    greedyNonNull [
      peer.presharedKeyFile
      (deriveSecret peer.pskLookup)
      (deriveSecret "${peer.interfaceName}-psk")
    ];

  toPeer = p: {
    inherit (p)
      publicKey
      persistentKeepalive;

    allowedIPs = p.ipv4 ++ p.ipv6;
    endpoint = p.selfEndpoint;
    name = p.hostName;
    preSharedKeyFile = derivePskFile p;
  };

  defaultCtor = {ipKey, toPeer, autoConfigKey}:
    {
      inherit toPeer;

      from = network: (mkIf network.self.found {
        inherit (network.self)
          listenPort
          privateKey
          privateKeyFile
          metric
        ;

        ${ipKey} = with network.self; ipv4 ++ ipv6;

        peers = lib.optionals
          network.autoConfig.${autoConfigKey}.peers.mesh.enable
          (map toPeer (attrValues network.peers.by-name));
      });
    };
in
rec {
  rmParent = attr:
    foldl' recursiveUpdate {}
      ( mapAttrsToList (k: v: v) attr );

  translate = {
    "networking.wg-quick" = defaultCtor {
      inherit toPeer;
      ipKey = "address";
      autoConfigKey = "networking.wg-quick";
    };

    "networking.wireguard" = defaultCtor {
      inherit toPeer;
      ipKey = "ips";
      autoConfigKey = "networking.wireguard";
    };

    "systemd.network.netdev" = rec {
      toPeer = p: {
        RouteTable = p.routeTable;
        PersistentKeepalive = p.persistentKeepalive;
        PublicKey = p.publicKey;
        Endpoint = p.selfEndpoint;
        AllowedIPs = p.ipv4 ++ p.ipv6;
      };

      from = network: {
        netdevConfig = {
          Kind = "wireguard";
          Name = network.interfaceName;
          # MTUBytes = "1300";
        };

        wireguardConfig = {
          PrivateKeyFile = network.self.privateKeyFile;
          ListenPort = network.self.listenPort;
        };

        wireguardPeers =
          map toPeer
            (builtins.attrValues network.peers.by-name);
      };
    };

    "services.rosenpass" = rec {
      toPeer = p: {
        device = p.interfaceName;
        peer = p.publicKey;
        endpoint = if (p.selfEndpoint != null)
          then "${p._endpoint.ip}:${p._endpoint.port - 1}"
        else null;
      };

      from = network: (with network.self; {
        public_key = publicKey;
        secret_key = privateKeyFile;
        endpoint = selfEndpoint;

        settings.peers = lib.optionals
          network.autoConfig."services.rosenpass".peers.mesh.enable
          (map toPeer (attrValues network.peers.by-name));
      });
    };
  };

  composeNetwork =
    mapAttrs' (net-name: network:
     let
       interfaceName =
         if network.interfaceName != null
         then network.interfaceName
         else net-name;

       by-name = mapAttrs (peer-name: peer:
         let
           socket = splitString ":" peer.endpoint;
           mkNodeOpt = name:
             if (peer.${name} != null)
             then peer.${name}
             else network.${name};

           inheritedAttrs = l: foldl' recursiveUpdate {} (map(i: { ${i} = mkNodeOpt i; }) l);
           new-data = inheritedAttrs [
             "listenPort"
             "domainName"
             "secretsLookup"
             "pskLookup"
             "preSharedKeyFile"
             "privateKeyFile"
           ];

           interfaceName =
             if peer.interfaceName
             then peer.interfaceName
             else interfaceName;

           hostName =
             if peer.hostName == null
             then peer-name
             else peer.hostName;
         in
           (peer // new-data //
           {
              inherit hostName interfaceName;

              fqdn =
                if ((mkNodeOpt "domainName") != null && hostName != null)
                then "${hostName}.${network.domainName}"
                else null;

              extraFQDNs =
                optionals
                  (peer.extraHostnames != [] && peer.domainName != null && hostName != null)
                  (map (n: "${n}.${peer.domainName}") peer.extraHostnames);

              _endpoint.ip = head socket;
              _endpoint.port = lib.strings.toInt (elemAt 2 socket);
           })) network.peers.by-name;

        by-group =
          let
            # first create flat list of all groups
            all-groups = (concatLists (mapAttrsToList(k: v: v.groups) by-name));
            per-groups = genAttrs all-groups
              (group-name:
                foldl'
                  (s: x: recursiveUpdate s { "${x.keyLookup}" = x;  })
                  {} (partition (p: elem group-name p.groups) (attrValues by-name)).right
              );
          in
            per-groups;
      in
        nameValuePair
        interfaceName
          (network // {
            inherit interfaceName;
            peers.by-group = by-group;
            peers.by-name = by-name;
          })
    );
}
