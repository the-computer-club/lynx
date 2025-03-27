# Silly tricks

## export network flake (nixos)

Particularly useful when an organizing a network with more than one member 
is give the network its own http/s accessible flake. 

This then can be administered within the organization policies it belongs to, 
and members may PR to it.

Example:
```nix
{ outputs = _: {
    modules.nixos.your-network = {
      wireguard.networks.your-network = {
        peers.by-name = { ... };
      };
    };
  };
}
```

```nix
imports = [
  inputs.network-config.nixosModules.network-module
];

wireguard.enable = true;
```


## wireguard names

get names from `wg show` output as defined
in `peers.by-name`

```nix
imports = [
  inputs.lynx.modules.nixos.wg-name
];

wireguard.named.enable = true;

environment.systemPackages = [
  inputs.lynx.packages.${pkgs.system}.wireguard-tools
];
```


```
interface: <iface>
  public key: <public key>
  private key: (hidden)
  listening port: 51820

peer: <peers.by-name.$0> (<pubkey>)
  allowed ips: <allowed ips>
  ...

```
