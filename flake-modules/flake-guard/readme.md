# flake-guard
```nix

{ # flake-module

  imports = [ lynx.flakeModules.flake-guard ];

  wireguard.networks.my-network = {
    # assumes same sop keys for all hosts.
    sopsLookup = "my-network"; 
    
    # assumes the same port for all hosts.
    listenPort = 51820;
    
    peers.by-name = { #
      hostname = {
        publicKey = "g72lA+Jsvp7ZEmXQGpJCrzMVrorSTjr6/kbD9aaLyX0=";
            # privateKeyFile = "....";
            # or 
            # sopsLookup = "my-network" (sops.secrets.${key})
            ipv4 = [ "172.16.0.1/32" ];
            ipv6 = [ "fc90::1" ];
            selfEndpoint = "example.com:51820";
        };
      };
    };
  };
}
```

```nix
# nixos module
{ config, lib, pkgs, ... }:
let
  net = config.networking.wireguard.networks.seclan;
in
{
  imports = [ lynx.nixosModules.flake-guard-host ];

  sops.secrets.my-network.mode = "0400";

  networking = {
    firewall.interfaces.eno1.allowedUDPPorts = [
      net.listenPort
    ];

    wireguard.networks.my-network.autoConfig = {
      interface = true; # automatically get ips & privatekey
      peers = true; # Automatic mesh
    };
  };
}

```


