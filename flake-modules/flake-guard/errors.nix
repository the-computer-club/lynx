{ config, lib, pkgs, ... }:
with lib;
{
  flake.nixosModules.flake-guard-exceptions = ({config,lib, ...}:
  {
    config.assertions = lib.mapAttrsToList (net-name: network: {
      condition = builtins.length (builtins.attrNames network.responsible) > 1;
      message =
        ''
        ${builtins.concatStringSep "\n"
          (mapAttrs (k: peer:
          ''
          flake-guard.networks.${net-name}.peers.${k}
          flake-guard.networks.${net-name}.peers.${k}.hostname = "${peer.hostname}"
          '') network.self.responsible)
         }

       this machine matches to:
       - flake-guard.hostname => ${config.flake-guard.hostname}
       - flake-guard.networks.${net-name}.self.hostname => ${config.flake-guard.networks.self.hostname}

       [flake-guard]
       multiple peers in ${net-name} are being matched with this host.
       To resolve this issue, only one peer must match with this host.
       '';
    }) config.flake-guard.networks
    ++

    (lib.mapAttrsToList(net-name: network: {
      condition = !network.found && network.autoConfig.interface.enable;

      message = ''
        `flake-guard.networks."${net-name}".self` cannot be found on this host.

        no peers in `wireguard.networks."${net-name}".peers.by-name.<hostname>.<?hostname>`
        match with `flake-guard.hostname = "${config.flake-guard.hostname}"`

        flake-guard.networks."${net-name}".autoConfig.interface.enable cannot be used until resolved.
      '';
    } config.networking.wireguard.interfaces)
    ++
    (lib.mapAttrsToList(net-name: network: {
      condition = (
        with network.autoConfig;
          interface.enable
          && ! network.peers.by-name ? "${config.flake-guard.hostname}"
      );
      message = ''
        no peers defined `flake-guard.networks.${net-name}.peers.by-name`
        match with `flake-guard.lookupKey` (${config.flake-guard.hostname})
        in this configuration
      '';
    }) config.flake-guard.networks));
  });
}
