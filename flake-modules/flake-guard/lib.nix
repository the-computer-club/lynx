{ lib, ... }:
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
  safeHead = list:
    if (builtins.length list) >= 1
    then (builtins.head list)
    else null;

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
      address = builtins.elemAt array 0;
      mask = builtins.elemAt array 1;
    in
    { inherit address mask; };

  deriveSecret = config: lookup:
    let x = lib.traceVal lookup;
    in
      if ((lib.traceVal (config ? "sops")) && config.sops.secrets ? "${x}" ) then
        [config.sops.secrets.${x}.path]
      else [];

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
             "nameAsFQDN"
           ];

           hostName =
             if peer.hostName == null
             then peer-name
             else peer.hostName;
         in
           (( inheritedData // peer) // {
             inherit interfaceName hostName;

             fqdn =
               if (!peer.nameAsFQDN) then
                if ((mkNodeOpt "domainName") != null && hostName != null)
                then "${hostName}.${network.domainName}"
                else null
              else hostName;

             extraFQDNs =
                optionals
                  (peer.extraHostNames != [] && peer.domainName != null && hostName != null)
                  (map (n: "${n}.${peer.domainName}") peer.extraHostNames);

             autoConfig = network.autoConfig // peer.autoConfig;
           })

           // {
             build = rec {
               ipv4 = map splitIp peer.ipv4;
               ipv6 = map splitIp peer.ipv6;
               first.ipv4 = safeHead ipv4;
               first.ipv6 = safeHead ipv6;
             };
           }
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
