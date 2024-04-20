# Flake-guard

Flake guard provides wireguard networks as a flake option.


### Flake-guard networks as inputs
```
# github:the-computer-club/automous-zones
{
  outputs = _: {
    flakeModules.gateway-zone.wireguard.networks.gateway-zone = {
      listenPort = 52180;
      peers.by-name = {
        hostname = {
          publicKey = "g72lA+Jsvp7ZEmXQGpJCrzMVrorSTjr6/kbD9aaLyX0=";
          selfEndpoint = "10.0.0.51";
        };

        vps = {
          publicKey = "ic/rfXxqoA4U0eaiL2VvVdkPIjvQL5p0lO/kk2lWZ0M=";
          selfEndpoint = "10.0.0.52";
        };
      };
    };
  };
}
```

```

inputs.nixpkgs.url    = "github:nixos/nixpkgs";
inputs.parts.url      = "github:the-computer-club/flake-parts";
inputs.lynx.url       = "github:the-computer-club/lynx";
inputs.aether-net.url = "github:the-computer-club/automous-zones";

outputs = inputs: inputs.parts.lib.mkFlake {inherit inputs;} ({ 
    systems = [ "x86_64-linux" ];
    imports = [
      inputs.lynx.flakeModules.flake-guard
      inputs.aether-net.flakeModules.gateway-zone
    ];

    wireguard.enable = true;
    
    nixosConfigurations.hostname = inputs.nixpkgs.lib.nixosSystem {       
      modules = [
        self.nixosModules.flake-guard-host
        {
           networking.wireguard.networks.gateway-zone.autoConfig = {
             interface = true;
             peers = true;
           };
        }
        ./home.nix
        ./home-hardware.nix
      ];
    
    };
})
```
