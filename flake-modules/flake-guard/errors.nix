{ config, lib, pkgs, ... }:
with lib;
{
  flake.nixosModules.wireguard-exceptions = ({config,lib, ...}:
  {
    config.assertions = lib.mapAttrsToList (net-name: network: {
      condition = builtins.length (builtins.attrNames network.responsible) > 1;
      message =
        ''
        ${builtins.concatStringSep "\n"
          (mapAttrs (k: peer:
          ''
          wireguard.networks.${net-name}.peers.${k}
          wireguard.networks.${net-name}.peers.${k}.hostname = "${peer.hostname}"
          '') network.self.responsible)
         }

       this machine matches to:
       - wireguard.hostname => ${config.wireguard.hostname}
       - wireguard.networks.${net-name}.self.hostname => ${config.wireguard.networks.self.hostname}

       [wireguard]
       multiple peers in ${net-name} are being matched with this host.
       To resolve this issue, only one peer must match with this host.
       '';
    }) config.wireguard.networks
    ++

    (lib.mapAttrsToList(net-name: network: {
      condition = !network.found && network.autoConfig.interface.enable;

      message = ''
        `wireguard.networks."${net-name}".self` cannot be found on this host.

        no peers in `wireguard.networks."${net-name}".peers.by-name.<hostname>.<?hostname>`
        match with `wireguard.hostname = "${config.wireguard.hostname}"`

        wireguard.networks."${net-name}".autoConfig.interface.enable cannot be used until resolved.
      '';
    } config.networking.wireguard.interfaces)
    ++
    (lib.mapAttrsToList(net-name: network: {
      condition = (
        with network.autoConfig;
          interface.enable
          && ! network.peers.by-name ? "${config.wireguard.hostname}"
      );
      message = ''
        no peers defined `wireguard.networks.${net-name}.peers.by-name`
        match with `wireguard.lookupKey` (${config.wireguard.hostname})
        in this configuration
      '';
    }) config.wireguard.networks));
  });
}
