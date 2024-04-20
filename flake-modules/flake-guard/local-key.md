# Local filesystem key


#### Flake
```nix
wireguard.enable = true;

wireguard.networks.my-network =
{
  listenPort = 52180;
  privateKeyFile = "/var/lib/wireguard/privatekey";
  
  peers.by-name = {
    workstation = {
      publicKey = "g72lA+Jsvp7ZEmXQGpJCrzMVrorSTjr6/kbD9aaLyX0=";
      selfEndpoint = "10.0.0.51";
    };
  
    vps = {
      publicKey = "ic/rfXxqoA4U0eaiL2VvVdkPIjvQL5p0lO/kk2lWZ0M=";
      selfEndpoint = "10.0.0.52";
    };
  };
}

nixosModules.my-network.networking.wireguard.networks.my-network.autoConfig = {
  interface = true;
  peers = true;
};

nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
  modules = [
    self.nixosModules.flake-guard-host
    self.nixosModules.my-network
    { 
      networking.hostName = "workstation";
      # interfaces.my-network.generatePrivateKeyFile = true;
    }
    ./workstation.nix
  ]
};

nixosConfigurations.vps = nixpkgs.lib.nixosSystem {
  modules = [
    self.nixosModules.flake-guard-host
    self.nixosModules.my-network
    { 
      networking.hostName = "vps";
      # interfaces.my-network.generatePrivateKeyFile = true;
    }
    ./vps.nix
  ]
};

```


#### Nixos Configuration
```nix
imports = [self.nixosModules.flake-guard-host];

networking.wireguard = {
  networks.my-network.autoConfig = {
    peers = true;
    interface = true;
  };

  # Useful for sharing with others.
};
```
