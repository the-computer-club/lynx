lib: wireguard-network:
with lib;
(mapAttrs (net-name: network:
     let
       by-name = mapAttrs (peer-name: peer:
          let
            repack = l: lib.foldl' lib.recursiveUpdate {} (map(i: { ${i} = mkGuardOpt i; }) l);

            mkGuardOpt = name:
              if (peer.${name} != null)
              then peer.${name}
              else network.${name};

            new-data = repack [
              "domainName" "enableACME"
              "acmeProviderUri" "acmeTrustedCertificateFiles"
              "hostsWriter" "interfaceWriter" "secretsLookup"
              "listenPort" "privateKeyFile"
            ];

            hosts = peer.extraHostnames ++ [peer.hostname];
          in
            ((peer
              // new-data
              //
            {
              keyLookup = peer-name;

              hostname =
                if peer.hostname == null
                then peer-name
                else peer.hostname;

              fqdn =
                if (mkGuardOpt "domainName") != null && peer.hostname != null
                then "${peer.hostname}.${network.domainName}"
                else null;

              extraFqdns =
                lib.optionals
                  (peer.extraHostnames != [] && peer.domainName != null && peer.hostname != null)
                  (map (n: "${n}.${peer.domainName}") peer.extraHostnames);
            }))
        ) network.peers.by-name;

        by-group =
          let
            # first create flat list of all groups
            all-groups = (lib.concatLists (mapAttrsToList(k: v: v.groups) by-name));
            per-groups = lib.genAttrs all-groups
              (group-name:
                builtins.foldl' (s: x: lib.recursiveUpdate s { "${x.keyLookup}" = x;  })
                  {}
                  (lib.partition (p: builtins.elem group-name p.groups)
                    (builtins.attrValues by-name)
                  ).right
              );
          in
            per-groups;
      in
        network // {
          interfaceName = net-name;
          peers.by-group = by-group;
          peers.by-name = by-name;
        }
    ) wireguard-network)
