{
  description = "flake example";

  inputs = {
    lynx.url = "../";
    parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
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
            hostname = "node1.vpn";
            ipv4 = ["172.16.169.1/32"];
            publicKey = "3rVr8zvOVcOxmlA41tpPoYAiZJcFDPX21D7MsVoUqFY=";
            privateKey = "MLYIn9QSMgzgoVAna3pGmy6UajzcrStN2d/546HmgEE=";
            selfEndpoint = "node1:51820";
          };

          node2 = {
            hostname = "node2.vpn";
            ipv4 = ["172.16.169.2/32"];
            publicKey = "hvoRk9k84yYcThG2qwilWuBQUJpBrgMs6dMBg7PD2Qc=";
            privateKey = "CHyebeznokFGkyo2WYWZWzdgWTug8wHnZjjsgsxFFlY=";
            selfEndpoint = "node2:51820";
          };
        };
      };

      flake.nixosModules.test-flake-guard-host = { config, ... }:
      {
        flake-guard.enable = true;
        flake-guard.networks = {
          testnet.autoConfig = {
            peers.enable = true;
            interface.enable = true;
            hosts.enable = true;
          };
        };

        networking.firewall.allowedUDPPorts = [
            config.flake-guard.networks.testnet.self.listenPort
        ];
      };

      flake.nixosConfigurations.flake-guard-test = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.flake-guard-host
          self.nixosModules.test-flake-guard-host
          { flake-guard.hostname = "node1"; }
        ];
      };

      perSystem = args@{ config, self', inputs', pkgs, lib, system, ... }:
        {
          packages.flake-guard-test =
            (pkgs.nixosTest {
              name = "flake-guard-host-test";

              nodes = {
                node1.imports = [
                  self.nixosModules.flake-guard-host
                  self.nixosModules.test-flake-guard-host
                ];

                node2.imports = [
                  self.nixosModules.flake-guard-host
                  self.nixosModules.test-flake-guard-host
                ];
              };

              testScript = ''
                  start_all()

                  node1.wait_for_unit("default.target")
                  node2.wait_for_unit("default.target")

                  node1.succeed("ping -c 3 node2")
                  node2.succeed("ping -c 3 node1")

                  node1.succeed("ping -c 3 172.16.169.2")
                  node2.succeed("ping -c 3 172.16.169.1")

                  node1.succeed("ping -c 3 node2.vpn")
                  node2.succeed("ping -c 3 node1.vpn")
              '';
            });

          packages.default = pkgs.mkShell {
            shellHook = ''
              alias build="nix flake update && nix build"
              alias repl="nix flake update && nix repl"
           '';
          };
        };
    });
}
