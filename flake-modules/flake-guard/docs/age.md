# Agenix

> [!TIP]
> `sopsLookup` is still used with age-nix. This will be resolved with
> [#6](https://github.com/the-computer-club/lynx/issues/6)
Using flakeguard with agenix has a slightly different configuration.

`wireguard.networks.<name>.sopsLookup` is defective when using agenix, since each secret in the repository has a unique `{key:value}` pair. 

Due to this, the same secret lookup cannot be used across multiple nixosConfigurations.



```nix
imports = [ inputs.lynx.flakeModules.flake-guard ];

wireguard.enable = true;
wireguard.networks.my-network = {
  listenPort = 52180;
  
  peers.by-name.workstation = {
    sopsLookup = "home-privatekey.age";
    publicKey = "g72lA+Jsvp7ZEmXQGpJCrzMVrorSTjr6/kbD9aaLyX0=";
    selfEndpoint = "10.0.0.51";
  };
  
  peers.by-name.vps = {
    sopsLookup = "vps-privatekey.age";
    publicKey = "ic/rfXxqoA4U0eaiL2VvVdkPIjvQL5p0lO/kk2lWZ0M=";
    selfEndpoint = "10.0.0.51";
  };
};

nixosModules.my-network = {
  networking.wireguard.networks.my-network.autoConfig = {
    peers = true;
    interface = true;
  };
};

nixosConfigurations = {
    vps = nixpkgs.lib.nixosSystem {
      modules = [
        ./vps/configuration.nix
        self.nixosModules.flake-guard-host
        self.nixosModules.my-network
        { networking.hostName = "vps"; }
      ];
    };
    
    workstation = nixpkgs.lib.nixosSystem {
      modules = [
        ./vps/configuration.nix
        self.nixosModules.flake-guard-host
        self.nixosModules.my-network
        { networking.hostName = "workstation"; }
      ];
    };
}
```
