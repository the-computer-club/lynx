# Silly tricks
```nix
{

  outputs = _: {
    nixosModules.network-module.wireguard.networks.your-network = {
      listenPort = 51820;
      peers.by-name = { ... };
    };
  };
}
```

```
imports = [
  inputs.network-config.nixosModules.network-module
];
```
