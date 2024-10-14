{ inputs, config, lib, pkgs, ... }:
let
  rootConfig = config;
  module = config.flake.nixosConfigurations.unit-test;
in
{
  flake.nixosConfigurations.unit-test = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./network.nix
      inputs.sops.nixosModules.sops
      inputs.lynx.nixosModules.flake-guard-host
      {
        nixpkgs.hostPlatform = "x86_64-linux";
        systemd.tmpfiles.rules = [
          "f /run/secrets/keys.txt 600 root root - ${./.}/flake-guard/keys.txt"
        ];

        sops.age.keyFile = "/run/secrets/keys.txt";
        sops.secrets."testnet".sopsFile = ./private-key.json;

        wireguard = {
          hostName = "nginx";

          defaults.autoConfig.openFirewall = true;
          networks.testnet = {
            secretsLookup = "testnet";
            peers.by-name.nginx.privateKey = lib.mkForce null;

            autoConfig."networking.wireguard" = {
              interface.enable = true;
              peers.mesh.enable = true;
            };
          };

          networks.global-test = {};
        };
      }
    ];
  };

  evalChecks.assertions =
    let networks =  module.config.wireguard.build.networks;
  [
    { assertion =
        builtins.all
          (net: net.self.privateKeyFile != null || net.self.privateKey != null)
          (builtins.filter(net: net.self.found)
            (builtins.attrValues networks));

      message = ''
        self was found, but the privateKeyFile was not.
      '';
    }
    { assertion =
          module.config.wireguard.defaults.autoConfig ==
            networks.global-test.autoConfig;

      message = ''
        defaults did not get carried down
      '';
    }
    { assertion =
        let inherit (module.config.wireguard.lib) deriveSecret;
        in
          (deriveSecret "testnet") != [];

      message = ''
        deriveSecret failed us. something's gone wrong with it.
      '';
    }
    { assertion = builtins.elem networks.testnet._responsible "nginx"
          && networks.testnet.self.found == false;

      message = ''
        `network._responsible` contains the correct information,
        but `network.self.found` was not triggered
      '';
    }
  ];
}
