args@{ options, config, lib, pkgs, ... }:
let
inherit (lib)
  mkOption
  mkEnableOption
  mkIf
  mkMerge
  mkRenamedOptionModule
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

inherit (import ./lib.nix)
  toPeers;

node-options = import ./node-options.nix args;
network-options = import ./network-options.nix args;
in
{
  config.flake.nixosModules.flake-guard-host = import ./nixos-module.nix config;

  options.wireguard = {
    secretsLookup.sops.enable = mkEnableOption ''
      enable looking up secrets via `sops.secrets ? <lookup>`.
      enabling this without age will not cause errors, and instead skip the check
      '';

    secretsLookup.age.enable = mkEnableOption ''
      enable looking up secrets via `age.secrets ? <lookup>`.
      enabling this without age will not cause errors, and instead skip the check
      '';

    defaults.interfaceWriter = mkOption {
      type = types.str;
      default = "networking.wireguard.interfaces";
    };

    defaults.hostsWriter = mkOption {
      type = types.str;
      default = "networking.hosts";
    };

    networks = mkOption {
      type = types.attrsOf (types.submodule network-options);
      default = {};
    };

    build.networks = mkOption {
      default = {};
      type = types.attrsOf (types.submodule {
        options = (
        lib.recursiveUpdate network-options.options
        {
          peers.by-group = mkOption {
            type = types.attrsOf types.attrsOf (types.submodule node-options);
            default = {};
          };
        });
      });
    };
  };

  config.wireguard.build.networks =
    (mapAttrs (net-name: network:
     let
        by-name = mapAttrs (peer-name: peer:
          let
            mkGuardOpt = name:
              if (peer.${name} != null)
              then peer.${name}
              else network.${name};

            hosts = peer.extraHostnames ++ [peer.hostname];
          in
            ((peer //
            {
              keyLookup = peer-name;
              hostname =
                if peer.hostname == null
                then peer-name
                else peer.hostname;

              fqdn =
                if (peer.domainName != null && peer.hostname != null)
                then "${peer.hostname}.${network.domainName}"
                else null;

              extraFqdn =
                lib.optionals
                  (peer.extraHostnames != [] && peer.domainName != null && peer.hostname != null)
                  (map (n: "${n}.${peer.domainName}") peer.extraHostnames);

              domainName = mkGuardOpt "domainName";
              acmeProviderUri = mkGuardOpt "acmeProviderUri";
              acmeTrustedCertificateFiles = "acmeTrustedCertificateFile";

              hostsWriter = mkGuardOpt "hostsWriter";
              interfaceWriter = mkGuardOpt "interfaceWriter";
              secretsLookup = mkGuardOpt "secretsLookup";
              listenPort = mkGuardOpt "listenPort";
              privateKeyFile = mkGuardOpt "privateKeyFile";
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
    ) config.wireguard.networks);
}