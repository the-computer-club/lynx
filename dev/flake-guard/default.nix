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
        wireguard.hostname = "acme";
        networking.hostName = "acme";
      }
    ];
  };

  perSystem = args@{ config, self', inputs', pkgs, lib, system, ... }:
  {
    packages.flake-guard-test =
      let
        test-certificates = pkgs.runCommandLocal "test-certificates" { } ''
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

        common = {config, ...}:
        {
          imports = [inputs.lynx.nixosModules.flake-guard-host];
          wireguard.defaults.autoConfig.openFirewall = true;
          wireguard.networks = rootConfig.wireguard.networks;

          security.pki.certificateFiles = [ "${test-certificates}/root_ca.crt" ];
          networking.firewall.allowedUDPPorts = [
            51820
          ];
        };

        open-server.networking.firewall.allowedTCPPorts = [ 443 ];
      in
      (pkgs.nixosTest {
        name = "flake-guard-host-test";
        nodes = {
          acme.imports = [
            common
            ./acme-server.nix
            { services.step-ca = {
                enable = true;
                intermediatePasswordFile = "${test-certificates}/intermediate-password-file";
                settings = {
                  root = "${test-certificates}/root_ca.crt";
                  crt = "${test-certificates}/intermediate_ca.crt";
                  key = "${test-certificates}/intermediate_ca.key";
                };
              };
            }
          ];

          nginx.imports = [
            common
            open-server
            ./nginx.nix
          ];

          caddy.imports = [
            common
            open-server
            ./caddy.nix
          ];

          userclient.imports = [common];
        };

        testScript = ''
            acme.start()
            acme.wait_for_unit("default.target")
            acme.wait_for_unit("network-online.target")

            nginx.start()
            userclient.start()
            caddy.start()

            nginx.wait_for_unit("default.target")
            userclient.wait_for_unit("default.target")
            caddy.wait_for_unit("default.target")

            acme.succeed("ping -c 3 nginx")
            acme.succeed("ping -c 3 caddy")

            nginx.succeed("ping -c 3 acme")
            nginx.succeed("ping -c 3 caddy")

            caddy.succeed("ping -c 3 acme")
            caddy.succeed("ping -c 3 nginx")

            acme.succeed("ping -c 3 172.16.169.2") # nginx.vpn
            acme.succeed("ping -c 3 172.16.169.3") # caddy.vpn

            caddy.succeed("ping -c 3 172.16.169.1") # acme.vpn
            caddy.succeed("ping -c 3 172.16.169.2") # nginx.vpn

            nginx.succeed("ping -c 3 172.16.169.1") # acme.vpn
            nginx.succeed("ping -c 3 172.16.169.3") # caddy.vpn

            acme.succeed("ping -c 3 nginx.vpn")
            acme.succeed("ping -c 3 caddy.vpn")

            nginx.succeed("ping -c 3 acme.vpn")
            nginx.succeed("ping -c 3 caddy.vpn")

            caddy.succeed("ping -c 3 acme.vpn")
            caddy.succeed("ping -c 3 nginx.vpn")

            acme.wait_until_succeeds("journalctl -o cat -u step-ca.service | grep '${pkgs.step-ca.version}'")
            acme.wait_for_unit("step-ca.service")

            nginx.wait_for_unit("acme-finished-nginx.target")

            userclient.succeed("curl https://nginx/ | grep \"Welcome to nginx!\"")
            userclient.succeed("curl https://nginx.vpn/ | grep \"Welcome to nginx!\"")

            caddy.wait_for_unit("caddy.service")
            userclient.succeed("curl https://caddy/ | grep \"Welcome to Caddy!\"")
            userclient.succeed("curl https://caddy.vpn/ | grep \"Welcome to Caddy!\"")
        '';
      });
  };
}
