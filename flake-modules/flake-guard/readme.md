# flake-guard

flake guard allows you to define your wireguard network once, and use it across multiple `nixosConfiguration` fields.

### Define your network.
- Step 1: create `wireguard-network.nix`
```nix
{ # flake-module
  imports = [ lynx.flakeModules.flake-guard ];

  wireguard.networks.my-network = {
    # assumes same sop keys for all hosts.
    # this also works with agenix
    sopsLookup = "my-network"; 
    
    # assumes the same port for all hosts.
    listenPort = 51820;
    
    peers.by-name = { #
      # WARNING: networking.hostName = "host1"; 
      # must match `host1 = ...` for `autoConfig` to work. (flake-guard-host)
      host1 = {
        publicKey = "g72lA+Jsvp7ZEmXQGpJCrzMVrorSTjr6/kbD9aaLyX0=";
            ipv4 = [ "172.16.0.1/32" ];
            ipv6 = [ "fc90::1/128" ];
            selfEndpoint = "example.com:51820";
        };
      };

      host2 = {
        publicKey = "ic/rfXxqoA4U0eaiL2VvVdkPIjvQL5p0lO/kk2lWZ0M=";
            ipv4 = [ "172.16.0.1/32" ];
            ipv6 = [ "fc90::1/128" ];
            selfEndpoint = "example.com:51820";
        };
      };
    };
  };
}
```

- Step 2:

Now create secrets for each nixosConfiguration this network is involved with. (or agenix equalivent)
```
EDITOR=emacs sops secrets/default.json
```


- Step 3: add a field named matching the `sopsLookup` value, and insert the output of `wg genkey`.

Repeat steps 2 through 3 for every nixosConfiguration in the network.


Inside each host where we participate in the network. 
```
{ self, config, lib, pkgs, ... }:
let
  net = config.networking.wireguard.networks;
in
{
  imports = [ self.nixosModules.flake-guard-host ];
  
  sops.secrets.my-network.mode = "0400";
  networking.firewall.interfaces = {
    eno1.allowedUDPPorts = [
      net.my-network.self.listenPort
    ];
    my-network.allowedTCPPorts = [ 22 80 443 ];
  };

  networking.wireguard.networks = {
    my-network.autoConfig = {
      # Automatically setup
      # `networking.wireguard.interfaces.<network-name>.{privateKeyFile,ips}`
      interface = true;
      # Settings `peers = true` is equalivent 
      # to a mesh network.
      peers = true;
    };
  };
}
```
Thats it, you're done.


### Non-mesh topology.
```
let net = config.networking.wireguard.networks."my-network"
in
{
  networking.wireguard.networks = {
    my-network.autoConfig.interface = true;
  };

  networking.wireguard.interfaces."my-network".peers = 
    with net.peers.by-name; [
      host2
    ];
}
```
