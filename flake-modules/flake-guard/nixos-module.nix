args@{ options, config, lib, pkgs, ... }:
with lib;
let
  inherit (import ./lib.nix args)
    toIpv4
    toIpv4Range
    toPeer
    rmParent
  ;

  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    mkRemovedOptionModule
    mkRenamedOptionModule
    mapAttrs'
    nameValuePair
    types
    optionalString
    optionals
  ;
  inherit (builtins)
    mapAttrs
  ;
  node-options = import ./node-options.nix args;
  network-options = import ./network-options.nix args;
  settings-options = import ./settings.nix args;
  cfg = config.flake-guard;

in
{
  imports = [
    (mkRenamedOptionModule
      [ "networking" "wireguard" "networks" ]
      [ "flake-guard" "networks" ])
  ];

  # config.assertions = [
  #   {
  #     condition = builtins.all mapAttrsToList(k: v: (!v.found && v.autoConfig.interface)) config.flake-guard.networks;
  #     message = "could not find self";
  #   }

  #   # {
  #   #   condition = mapAttrsToList(k: v: (v.privateKeyFile != null && v.privateKey != null)) config.flake-guard.networks;
  #   #   message = "privateKey & privateKeyFile are set";
  #   # }
  # ];

  options.flake-guard = {
    enable = mkEnableOption "enable flake-guard nixos module";

    flake-parts = {
      enable = mkEnable "built from flake-parts scope";
      passthru = mkOption {
        type = types.unspecified;
        default = null;
      };
    };

    hostname = mkOption {
      type = types.str;
      default = config.networking.hostName;
    };

    _loader-stub = mkOption {
      type = types.functionTo (types.attrsOf
        (types.submodule network-options)
      );

      default = (import ./stub.nix) lib;
    };

    defaults = mkOption {
      type = (types.submodule setting-options);
      default.autoConfig = {
        "networking.wireguard.interfaces" = {
          ips.enable = lib.mkDefault true;
          privateKey.enable = lib.mkDefault true;
          peers.enable = lib.mkDefault true;
        };
        "networking.hosts".Fqdns = lib.mkDefault true;
      };
    };

    networks = mkOption {
      default = {};
      type = types.attrsOf (types.submodule {
        options = network-options.options;
      });
    };
  };

  # user input / symmetric to flakeModule toplevel
  config.flake-guard.networks =
    mkIf cfg.flake-parts.enable
      cfg.flake-parts.passthru;

  # apply loader stub-loader onto data
  config.flake-guard.build.stubbed =
    cfg._stub-loader
      cfg.networks;

  # build network with `self` selected
  config.flake-guard.build.networks = mkIf cfg.enable
    (mapAttrs (net-name: network:
      let
        _responsible =
          (mapAttrs (k: x:
            k == cfg.hostname
            || x.hostname == cfg.hostname
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
          inherit (network) listenPort autoConfig sops age;
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
      }) cfg.build.stubbed);

  # build the wireguard interfaces via
  config.networking.wireguard.interfaces =
    mapAttrs
      (net-name: network:
        (mkIf (
          network.autoConfig.interface.enable && network.self.found
          && (network.self.interfaceWriter == "networking.wireguard.interfaces"))
          {
            inherit (network.self) listenPort;

            ips = lib.optionals (network.autoConfig.interface.enable)
              (network.self.ipv4 ++ network.self.ipv6);

            privateKeyFile = network.self.privateKeyFile;

            privateKey = network.self.privateKey;

            peers = lib.optionals network.autoConfig.peers.enable
              (lib.mapAttrsToList (k: v: toPeer v) network.peers.by-name);
          }
        )
      ) cfg.build.networks;

  # build the hostnames via
  config.networking.hosts =
    rmParent (mapAttrs (network-name: network:
      (mkIf
        network.autoConfig."networking.hosts".enable
        (builtins.foldl' lib.recursiveUpdate {}
          (lib.mapAttrsToList
            (k: peer: builtins.foldl' lib.recursiveUpdate {}
              (map (real-ip:
                let
                  ip = builtins.head (builtins.split "/" real-ip);
                in
                  { "${ip}" =
                      (lib.optional peer.writeHostname.enable peer.hostname)
                      ++ (lib.optionals peer.writeHostname.enable peer.extraHostnames)
                      ++ (lib.optional (peer.writeFqdn.enable && peer.fqdn != null) peer.fqdn)
                      ++ (lib.optional peer.writeFqdns.enable peer.extraFqdns);
                  })
                (peer.ipv4 ++ peer.ipv6)
              )
            ) network.peers.by-name
          )
        )
      )) cfg.build.networks);


  # NOTE: services.nginx.virtualHosts.<name>.enableACME will automatically fill in
  # security.acme.certs
  # ---
  # build acme certs via
  config.security.acme.certs =
    (rmParent (lib.mapAttrs (network-name: network:
      lib.mkIf network.self.autoConfig."security.acme.certs".enable
      {
        ${network.self.fqdn} = {
          domain = network.self.fqdn;
          extraDomainNames = network.self.extraFqdns;
          server = network.autoConfig."security";
        };
      }) cfg.build.networks)
    );
}
