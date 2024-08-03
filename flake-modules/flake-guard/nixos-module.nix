rootConfig: {config, lib, ...}:
with lib;
{
  imports = [
    (mkRenamedOptionModule
      [ "networking" "wireguard" "networks" ]
      [ "flake-guard" "networks" ])
  ];

  options.flake-guard = {
    enable = mkEnableOption "enable flake-guard nixos module";

    hostname = mkOption {
      type = types.str;
      default = config.networking.hostName;
    };

    networks = mkOption {
      default = {};
      type = types.attrsOf (types.submodule {
        options = network-options.options // {
          autoConfig = {
            interface.enable = mkEnableOption "automatically generate the underlying network interface";
            peers.enable = mkEnableOption "automatically generate the peers -- this will add all peers in the network to the interface.";
            hosts.enable = mkEnableOption "automatically generate `etc.hostnames` enteries for each peer";
          };

          interfaceName = mkOption {
            type = types.nullOr types.str;
            default = null;
          };

          interfaceWriter = mkOption {
            type = types.enum [ "networking.wireguard.interfaces" ];
            default = "networking.wireguard.interfaces";
          };

          hostsWriter = mkOption {
            type = types.enum [ "networking.hosts" ];
            default = "networking.hosts";
          };

          peers = {
            by-name = mkOption {
              type = types.attrsOf (types.submodule node-options);
              default = {};
            };

            by-group = mkOption {
              type = types.attrsOf types.attrOf node-options;
              default = {};
            };
          };

          _responsible = mkOption {
            type = types.attrsOf types.bool;
            default = [];
          };

          self = mkOption {
            type = types.attrsOf types.unspecified;
            default = {};
          };
        };
      });
    };
  };

  config.flake-guard.networks = mkIf config.flake-guard.enable
    (mapAttrs (net-name: network:
      let
        _responsible =
          (mapAttrs (k: x:
            k == config.flake-guard.hostname
            || x.hostname == config.flake-guard.hostname
          ) network.peers.by-name);

        self-name =
          let
            names =
              builtins.filter(p: p.val)
                (lib.mapAttrsToList (k: v: {key=k; val=v;}) _responsible);
          in
            if (builtins.length names) == 1
            then (builtins.head names).key
            else null;

        peer-data = network.peers.by-name.${self-name};

        network-defaults = {
          inherit (network) listenPort hostsWriter interfaceWriter;
        };

      in network // {
        inherit _responsible;
        self = (mkIf (self-name != null)
          ((peer-data // network-defaults) //
           {
             found = true;
             privateKeyFile =
               let
                 deriveSecret = lookup:
                   map (backend:
                     if (config ? backend && config.${backend}.secrets ? lookup) then
                       config.${backend}.secrets.${lookup}
                     else null
                   ) ["sops" "age"];
               in
                 if (self-name != null)
                 then
                   (builtins.head (builtins.filter (x: x == null)
                     (map (x: if (x != null) then x else null) [
                       peer-data.privateKeyFile
                       network.privateKeyFile
                       (deriveSecret peer-data.secretsLookup)
                       (deriveSecret network.privateKeyFile)
                     ])
                   ))
                 else null;
           }));
      }) rootConfig.build.networks);
}
