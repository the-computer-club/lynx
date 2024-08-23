{ config, lib, pkgs, ... }:
rec {
  toPeer = p: {
    inherit (p)
      publicKey
      persistentKeepalive;
    allowedIPs = p.ipv4 ++ p.ipv6;
    endpoint = p.selfEndpoint;
  };

  rmParent = attr:
    builtins.foldl' lib.recursiveUpdate {}
      ( lib.mapAttrsToList (k: v: v) attr );

  toIpv4Range = peers:
    map (peer:
      let
        list = (builtins.splitString "/" ip);
        ip = builtins.head list;
        cidr = builtins.elemAt list 2;
      in
        { inherit ip cidr; data=peer; }
    ) peers;

  toIpv4 = ip: builtins.head (builtins.splitString "/" ip);
}
