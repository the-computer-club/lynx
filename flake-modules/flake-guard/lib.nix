{ config, lib, pkgs, ... }:

let
inherit (lib)
  mkOption
  mkEnableOption
  mkIf
  mkMerge
  types
  mapAttrs
  mapAttrs'
  attrValues'
  attrNames
  partition
  nameValuePair
  mapAttrsToList
  recursiveUpdate
  ;
in
rec {
  toPeer = p: {
    inherit (p)
      meta
      publicKey
      persistentKeepalive;
    allowedIPs = p.ipv4 ++ p.ipv6;
    endpoint = p.selfEndpoint;
  };

  toIpv4Range = ips:
    map (ip:
      let
        list = (builtins.splitString "/" ip);
        ip = builtins.head list;
        cidr = builtins.elemAt 2 list;
      in
        { inherit ip cidr; }
    ) ips;

  toIpv4 = ip: builtins.head (builtins.splitString "/" ip);


  # interlace =
  #   s: a: b:
  #   let
  #     partition = lib.partition (x: x) s;
  #   in
  #     lib.fold' (s: x: s ++ [x]) s (lib.zip s a b);

  # shape =
  # {

  #   # all macines interlock with each other
  #   #  *---*
  #   #   \ /
  #   #    *
  #   #
  #   # [wireguard.networks.*] :: -> flake-module
  #   mesh = network:
  #     {
  #       wireguard
  #         .build
  #         .networks
  #         .${network.network-name}
  #         .peers
  #         .by-name
  #       =
  #         builtins.genAttrs (x: {
  #           peers = map toPeer (builtins.attrValues network.peers.by-name);
  #         })
  #         (attrNames network.peers.by-name);
  #     };

  #   # builtins.attrValues peers-by-name;

  #   # chain
  #   # *-> *-> ...
  #   #
  #   # TODO:
  #   #  interlace peer list into this where host is a peer who has an endpoint
  #   #  home->host->peer->host->peer->...
  #   #
  #   # [wireguard.networks.*] :: -> flake-module
  #   proxychain = network:
  #     let
  #       part = lib.partition (p: p.selfEndpoint != null) network.peers.by-name;
  #       gateways = part.right;
  #       clients = part.wrong;


  #       peers = attrValues'
  #         (builtins.zipAttrsWith (k: v: { name=k; value=v; })
  #           network.peers-by.name);

  #       intersect-name  = attr: lib.intersect (map (p: p.name) (attrValues' peers)) (builtins.attrNames attr);

  #       clients-names = intersect-name clients;
  #       gateways-names = intersect-name gateways;

  #       fin = { i=0; remaining = peers; modules = []; };

  #       modules = lib.foldl' (s: v:
  #         let
  #           prev-peer = builtins.head s.remaining;

  #           remaining =
  #             builtins.tail s.remaining;

  #           next-peer = builtins.head remaining;
  #         in
  #       {
  #         inherit remaining;
  #         i = s.i + 1;
  #         modules = s.modules ++ [
  #           ({...}: {
  #             wireguard
  #               .build
  #               .networks
  #               .${network.network-name}
  #               .peers
  #               .by-name
  #               .${prev-peer.name}
  #               .peers = [ next-peer.value ];
  #           })
  #         ];
  #       }) fin fin.remaining;

  #     in
  #       mkMerge modules;

  #   #    *
  #   #   /|\
  #   #  * * *
  #   #
  #   star = network:
  #     let
  #       part = lib.partition (p: p.selfEndpoint != null) network.peers.by-name;
  #       gateways = part.right;
  #       clients = part.wrong;

  #     in
  #       {
  #         wireguard.build.networks.${network.network-name}.peers.by-name =
  #           mapAttrs (k: x: {
  #             peers = map toPeer
  #               (if x.selfEndpoint
  #                  then clients ++ gateways
  #                  else gateways
  #               );

  #           }) network.peers.by-name;
  #       };
  #       # if hosting
  #       #   then map toPeer clients ++ gateways
  #       #   else map toPeer gateways;


  #   nobody = _: {};
  # };
}
