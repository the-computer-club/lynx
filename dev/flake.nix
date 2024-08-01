{
  description = "flake example";

  inputs = {
    lynx.url = "../";
    parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    profile-parts.url = "github:adamcstephens/profile-parts";
    disko.url = "github:nix-community/disko";
    # deploy-rs.url = "github:adamcstephens/profile-parts";
  };

  outputs = inputs@{self, parts, lynx, nixpkgs, ...}:
    parts.lib.mkFlake { inherit inputs; }
    ({ config, withSystem, flake-parts-lib, ... }:
    let
      rootConfig = config;
    in
    {
      systems = ["x86_64-linux"];
      imports =
        [ lynx.flakeModules.builtins ]
        ++
        (with lynx.flakeModules; [
          ../flake-modules/builtins/toplevel.nix
          ../examples/dogfood.nix
          ../examples/nixos-module.nix
          ../examples/flake-module.nix

          deploy-rs
          lynx-docs
          flake-guard
        ]);

      lynx.docgen.repository.baseUri = "github.com/";

      lynx.docgen.flakeModules = [
        lynx.flakeModules.deploy-rs
        lynx.flakeModules.lynx-docs
        lynx.flakeModules.wireguard
      ];

      lynx.docgen.nixosModules = [
        lynx.nixosModules.globals
      ];

      wireguard.networks.testnet = {
        listenPort = 51820;
        peers.by-name = {
          node1 = {
            ipv4 = ["172.22.169.1/32"];
            publicKeyFile = "de0spLlB+yBuV5dZaEkgxaAREhcU9MExnze3HRCdh2c=" ;
            privateKeyFile = ../flake-modules/flake-guard/testing/snakeoil-host1;
            hostname = "node1.vpn";
            selfEndpoint = "node1";
          };

          node2 = {
            hostname = "node2.vpn";
            ipv4 = ["172.22.169.2/32"];
            publicKeyFile = "yKzBbJ1F693FNXMdZ9BpIkQ9oVv3cTSMpdbUKpOZg0o=";
            privateKeyFile = ../flake-modules/flake-guard/testing/snakeoil-host2;
            selfEndpoint = "node2";
          };
        };
      };


      flake.nixosModules.test-flake-guard-host = { config, ... }:
      {
        flake-guard.networks = {
          testnet.autoConfig = {
            peers.enable = true;
            interface.enable = true;
            # hostnames.enable = true;
          };
        };

        networking.firewall.interfaces =
          let
            net = config.flake-guard.networks;
          in
          {
            eno1.allowedUDPPorts = [
              net.testnet.self.listenPort
            ];
          };
      };

      perSystem = args@{ config, self', inputs', pkgs, lib, system, ... }:
        {
          packages.flake-guard-test =
            pkgs.nixosTest {
              name = "flake-guard-host-test";

              nodes.node1.imports = [
                self.nixosModules.flake-guard-host
                self.nixosModules.test-flake-guard-host
              ];

              nodes.node2.import = [
                self.nixosModules.flake-guard-host
                self.nixosModules.test-flake-guard-host
              ];

              testScript = ''
                  start_all()
                  node1.wait_for_target("networking.target")
                  node2.wait_for_target("networking.target")

                  node1.succeed("ping -c 3 node2")
                  node2.succeed("ping -c 3 node1")

                  node1.succeed("ping -c 3 node2.vpn")
                  node2.succeed("ping -c 3 node1.vpn")
              '';
            };

          packages.default = pkgs.mkShell {
            shellHook = ''
              alias build="nix flake update && nix build"
              alias repl="nix flake update && nix repl"
           '';
          };
        };
    });
}
