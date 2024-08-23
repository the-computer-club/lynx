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
        lynx.flakeModules.flake-guard
      ];

      lynx.docgen.nixosModules = [
        lynx.nixosModules.globals
      ];

      wireguard.networks.testnet = {
        listenPort = 51820;
        acmeProviderUri = "https://acme:8443/acme/testnet/directory";
        domainName = "vpn";

        peers.by-name = {
          acme = {
            ipv4 = ["172.16.169.1/32"];
            publicKey = "3rVr8zvOVcOxmlA41tpPoYAiZJcFDPX21D7MsVoUqFY=";
            privateKey = "MLYIn9QSMgzgoVAna3pGmy6UajzcrStN2d/546HmgEE=";
            selfEndpoint = "acme:51820";
          };

          client = {
            ipv4 = ["172.16.169.2/32"];
            publicKey = "hvoRk9k84yYcThG2qwilWuBQUJpBrgMs6dMBg7PD2Qc=";
            privateKey = "CHyebeznokFGkyo2WYWZWzdgWTug8wHnZjjsgsxFFlY=";
            selfEndpoint = "client:51820";
          };

          caddy = {
            ipv4 = ["172.16.169.3/32"];
            publicKey = "wR9cRwbvNO8ogCamR5xL2Zjh+LLBtGdjf3rj6uhlml8=";
            privateKey = "8HmxTjhd/fw2Om2EPO7hkJEbSKn4P9mFhA01ddrCj08=";
            selfEndpoint = "caddy:51820";
          };

          tester = {
            ipv4 = ["172.16.169.4/32"];
            publicKey = "4j2NKmVgE/3iCcFbmtq6Pmvz8HDShI+jRlkEdDmKjmk=";
            privateKey = "yCX0xVDvnIhhFuo/xehG16IS1nKaNMT7cI5YIxwMGXs=";
            selfEndpoint = "tester:51820";
          };
        };
      };

      flake.nixosModules.test-flake-guard-host = { config, ... }:
      {
        flake-guard = {
          enable = true;
          networks.testnet.autoConfig = {
            peers.enable = true;
            interface.enable = true;
            hosts.enable = true;
          };
        };

        networking.firewall.allowedUDPPorts = [
          config.flake-guard.networks.testnet.self.listenPort
          80
          443
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
            in
            (pkgs.nixosTest {
              name = "flake-guard-host-test";

              nodes = {
                acme.imports =
                [
                  self.nixosModules.flake-guard-host
                  self.nixosModules.test-flake-guard-host
                  {
                    security.pki.certificateFiles = [ "${test-certificates}/root_ca.crt" ];
                    services.step-ca = {
                      enable = true;
                      address = "[::]";
                      port = 8443;
                      openFirewall = true;
                      intermediatePasswordFile = "${test-certificates}/intermediate-password-file";
                      settings = {
                        dnsNames = [ "acme" "acme.vpn" ];
                        root = "${test-certificates}/root_ca.crt";
                        crt = "${test-certificates}/intermediate_ca.crt";
                        key = "${test-certificates}/intermediate_ca.key";
                        db = {
                          type = "badger";
                          dataSource = "/var/lib/step-ca/db";
                        };
                        authority = {
                          provisioners = [
                            {
                              type = "ACME";
                              name = "acme";
                            }
                          ];
                        };
                      };
                    };
                  }
                ];

                client.imports = [
                  self.nixosModules.flake-guard-host
                  self.nixosModules.test-flake-guard-host
                  {
                    security.pki.certificateFiles = [ "${test-certificates}/root_ca.crt" ];
                    networking.firewall.allowedTCPPorts = [ 80 443 ];
                    security.acme.acceptTerms = true;
                    security.acme.defaults = {
                      email = "nginx@example.org";
                      server = "https://acme:8443/acme/acme/directory";
                    };
                    services.nginx = {
                      enable = true;

                      virtualHosts."client.vpn" = {
                        forceSSL = true;
                        enableACME = true;
                      };

                      virtualHosts."client" = {
                        forceSSL = true;
                        enableACME = true;
                      };
                    };
                  }
                ];

                caddy.imports =[
                  self.nixosModules.flake-guard-host
                  self.nixosModules.test-flake-guard-host
                  {
                    security.pki.certificateFiles = [ "${test-certificates}/root_ca.crt" ];
                    networking.firewall.allowedTCPPorts = [ 80 443 ];
                    services.caddy =
                      let conf =
                        ''
                          respond "Welcome to Caddy!"
                          tls caddy@example.org {
                            ca https://acme:8443/acme/acme/directory
                          }
                        '';
                      in
                    {
                      enable = true;
                      virtualHosts."caddy.vpn".extraConfig = conf;
                      virtualHosts."caddy".extraConfig = conf;
                    };
                  }
                ];

                tester.imports = [
                  { security.pki.certificateFiles = [ "${test-certificates}/root_ca.crt" ]; }
                  self.nixosModules.flake-guard-host
                  self.nixosModules.test-flake-guard-host
                ];
              };

              testScript = ''
                  acme.start()
                  acme.wait_for_unit("default.target")
                  acme.wait_for_unit("network-online.target")

                  client.start()
                  tester.start()
                  caddy.start()

                  client.wait_for_unit("default.target")
                  tester.wait_for_unit("default.target")
                  caddy.wait_for_unit("default.target")

                  acme.succeed("ping -c 3 client")
                  acme.succeed("ping -c 3 caddy")

                  client.succeed("ping -c 3 acme")
                  client.succeed("ping -c 3 caddy")

                  caddy.succeed("ping -c 3 acme")
                  caddy.succeed("ping -c 3 client")

                  acme.succeed("ping -c 3 172.16.169.2") # client.vpn
                  acme.succeed("ping -c 3 172.16.169.3") # caddy.vpn

                  caddy.succeed("ping -c 3 172.16.169.1") # acme.vpn
                  caddy.succeed("ping -c 3 172.16.169.2") # client.vpn

                  client.succeed("ping -c 3 172.16.169.1") # acme.vpn
                  client.succeed("ping -c 3 172.16.169.3") # caddy.vpn

                  acme.succeed("ping -c 3 client.vpn")
                  acme.succeed("ping -c 3 caddy.vpn")

                  client.succeed("ping -c 3 acme.vpn")
                  client.succeed("ping -c 3 caddy.vpn")

                  caddy.succeed("ping -c 3 acme.vpn")
                  caddy.succeed("ping -c 3 client.vpn")

                  acme.wait_until_succeeds("journalctl -o cat -u step-ca.service | grep '${pkgs.step-ca.version}'")
                  acme.wait_for_unit("step-ca.service")

                  client.wait_for_unit("acme-finished-client.target")
                  tester.succeed("curl https://client/ | grep \"Welcome to nginx!\"")
                  tester.succeed("curl https://client.vpn/ | grep \"Welcome to nginx!\"")

                  caddy.wait_for_unit("caddy.service")
                  tester.succeed("curl https://caddy/ | grep \"Welcome to Caddy!\"")
                  tester.succeed("curl https://caddy.vpn/ | grep \"Welcome to Caddy!\"")

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
