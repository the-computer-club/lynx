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
  ;

  inherit (builtins)
    splitString
    head
    elemAt
    elem
    foldl'
    attrValues
  ;
in
rec {
  toPeer = p: {
    inherit (p)
      publicKey
      persistentKeepalive;
    allowedIPs = p.ipv4 ++ p.ipv6;
    endpoint = p.selfEndpoint;
  };

  toRosenPeer = p: {
    device = p.interfaceName;
    peer = p.publicKey;
    endpoint = p.selfEndpoint;
  };

  rmParent = attr:
    foldl' recursiveUpdate {}
      ( mapAttrsToList (k: v: v) attr );

  toIpv4Range = peers:
    map (peer:
      let
        list = (splitString "/" ip);
        ip = head list;
        cidr = elemAt list 2;
      in
        { inherit ip cidr; data=peer; }
    ) peers;


  splitIp = ip:
    let
      array = lib.splitString "/" ip;
      address = builtins.elemAt 0 array;
      mask = builtins.elemAt 1 array;
    in
    { inherit address mask; };

  toIpv4 = ip: head (splitString "/" ip);

  composeNetwork =
    mapAttrs (net-name: network:
     let
       interfaceName =
         if network.interfaceName != null
         then network.interfaceName
         else net-name;

       by-name = mapAttrs (peer-name: peer:
         let
           mkNodeOpt = name:
             if (peer.${name} != null)
             then peer.${name}
             else network.${name};

           inheritedAttrs = l: foldl' recursiveUpdate {} (map(i: { ${i} = mkNodeOpt i; }) l);
           inheritedData = inheritedAttrs [
             "listenPort"
             "domainName"
             "secretsLookup"
             "privateKeyFile"
           ];

           hostName =
             if peer.hostName == null
             then peer-name
             else peer.hostName;
         in
           ({
             inherit interfaceName;
             inherit hostName;
             build = rec {
               ipv4 = map splitIp peer.ipv4;
               ipv6 = map splitIp peer.ipv6;
               first.ipv4 = builtins.head ipv4;
               first.ipv6 = builtins.head ipv6;
             };
             fqdn =
                if ((mkNodeOpt "domainName") != null && hostName != null)
                then "${hostName}.${network.domainName}"
                else null;

             extraFQDNs =
                optionals
                  (peer.extraHostnames != [] && peer.domainName != null && hostName != null)
                  (map (n: "${n}.${peer.domainName}") peer.extraHostnames);

             autoConfig = network.autoConfig // peer.autoConfig;
           } // inheritedData)
           // peer
       ) network.peers.by-name;

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
            {};
            # per-groups;
      in
        # nameValuePair
        # interfaceName
          (network // {
            inherit interfaceName;
            peers.by-group = by-group;
            peers.by-name = by-name;
          })
    );
}
