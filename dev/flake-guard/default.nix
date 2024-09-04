{inputs, config, self, ...}:
let rootConfig = config;
in {
  imports = [
    inputs.lynx.flakeModules.flake-guard
    ./network.nix
  ];

  flake.nixosConfigurations.acme = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      # config.flake.nixosModules.flake-guard-host
      {
        wireguard.enable = true;
        wireguard.hostname = "acme";
        networking.hostName = "acme";
      }
    ];
  };

  perSystem = args@{ config, self', inputs', pkgs, lib, system, ... }:
  {
    packages.test-certificates = pkgs.runCommandLocal "test-certificates" {} ''
      mkdir -p $out
      echo insecure-root-password > $out/root-password-file
      echo insecure-intermediate-password > $out/intermediate-password-file

      ${pkgs.step-cli}/bin/step certificate create "TEST Root CA" $out/root_ca.crt $out/root_ca.key --password-file=$out/root-password-file --profile root-ca
      ${pkgs.step-cli}/bin/step certificate create "TEST Intermediate CA" $out/intermediate_ca.crt $out/intermediate_ca.key \
        --password-file=$out/intermediate-password-file \
        --profile intermediate-ca \
        --ca-password-file=$out/root-password-file \
        --ca $out/root_ca.crt \
        --ca-key $out/root_ca.key
    '';

    packages.test-acme = pkgs.callPackage ./tests/acme/vmtest.nix {
      nodes = import ./tests/acme/nodes.nix args;
    };

    packages.test-vxlan = pkgs.callPackage ./tests/vxlan/vmtest.nix {
      nodes = import ./tests/acme/nodes.nix args;
    };

  };
}
