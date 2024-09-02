# wireguard
> [!TIP]
> If you do not have a secrets-backend configured yet. 
> The option `privateKeyFile` can used as a substitute for `secretsLookup`.

this allows you to define your wireguard network once, and use it across multiple `nixosConfiguration` fields.


<details>
<summary><b>1. Install Flake-guard</b></summary>


## [Flakes](https://wiki.nixos.org/wiki/Flakes)

```nix
{
  inputs.nixpkgs.url = "github:nixos/nixpkgs";
  inputs.parts.url = "github:hercules-ci/flake-parts";
  inputs.lynx.url = "github:the-computer-club/lynx";
  
  outputs = { self, nixpkgs, lynx }: {
    # change `yourhostname` to your actual hostname
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      # customize to your system
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        lynx.nixosModules.flake-guard-host
      ];
    };
  };
}
```


## [Flake-parts](https://flake.parts/)

```nix
{
  inputs.lynx.url = "github:the-computer-club/lynx";
  
  outputs = inputs@{self, parts, lynx, nixpkgs, ...}:
    parts.lib.mkFlake { inherit inputs; }
    ({ config, ... }: {
      imports = [ lynx.flakeModules.flake-guard ];
        
      flake.nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
        modules = [
          ./configuration.nix
          lynx.nixosModules.flake-guard-host
          { wireguard.enable = true; 
            wireguard.networks = config.wireguard.networks;
          }
        ];
      };
    };
  });
}
```
</details>

<details>
<summary><b>2. Setting up secrets</b></summary>

## Setting up secrets
> [!TIP]
> It is a common strategy to generate a wireguard key for each host, and then reference them all the same under the same namespace. Under each nixos-module context, the underlying value evaluates to a different secret.
> The examples below also follow this strategy.
> If not specified, flake-guard assumes the network name as the `secretsLookup` as a last-shot effort.


#### Secrets Backends supported are

- [agenix](https://github.com/ryantm/agenix)
- [sops-nix](https://github.com/Mic92/sops-nix)
- `privateKeyFile`
- `privateKey` (For testing purposes only)


The field `secretsLookup` will be used to evaluate `config.<secretsBackend>.secrets.<secretsLookup>`.
upon each host that loads `lynx.nixosModules.flake-guard-host`.


- `wireguard.networks.<NETWORK>.secretsLookup`
- `wireguard.networks.<NETWORK>.peers.by-name.<HOSTNAME>.secretsLookup`


Now create secrets for each nixosConfiguration this network is involved with.


Generate an encrypted secret for every host in the network, following the template below, add the following code to your project. (If you're using agenix, this example is for sops. Refer to agenix documentation [for now].)


---
### Sops

```sh
EDITOR=emacs sops secrets.json
```

```json
# secrets.json
{ "your-network": "AFN6afBcZyzKnjkdBztgEpVH3mmlcNUEo5vtDQuqy0s=" }
```


```nix
sops.secrets."your-network".mode = "0400";
```

---
### Age


```
EDITOR=emacs agenix -e host1-your-network.age
```


paste in the secret.
```
AFN6afBcZyzKnjkdBztgEpVH3mmlcNUEo5vtDQuqy0s=
```


add the following configuration to your hosts. 
Where each host appropriately knows its own secrets.
```
age.secrets."your-network".file = ./host1-your-network.age;
```

---

### privateKeyFile
Using the command `wg genkey`, create a unique file on every host machine at the location specified in this option.


---

### privateKey
The directive included is only for testing. 
Usage outside those means may result in damages. 
</details>

<details>
<summary><b>3. Defining a Network</b></summary>


## Define your network.
Define your network as such.

```nix
# network.nix
{ ... }:
{ 
  wireguard.enable = true;
  <age|sops>.secrets.your-network.mode = "0400";
  
  wireguard.networks.your-network = {
    listenPort = 51820;
    domainName = "vpn";
    secretsLookup = "your-network"; 

    autoConfig = {
      openFirewall = true;
    
      "networking.wireguard" = {
        # Automatically setup 
        # `networking.wireguard.interfaces.<ip | privateKey | privateKeyFile>`
        interface.enable = true;
        
        # Just add every peer from network.
        peers.mesh.enable = true;
      };

      "networking.hosts" = {
        # Modify the /etc/hosts to include nodes from the network
        enable = true;
        
        # Use add <hostname>.<domainName>.
        FQDNs.enable = true;
        # names.enable # bare names
      };
    };

    peers.by-name = {
      host1 = {
        publicKey = "g72lA+Jsvp7ZEmXQGpJCrzMVrorSTjr6/kbD9aaLyX0=";
        ipv4 = [ "172.16.0.1/32" ];
        selfEndpoint = "10.0.0.2:51820";
      };
    
      host2 = {
        publicKey = "ic/rfXxqoA4U0eaiL2VvVdkPIjvQL5p0lO/kk2lWZ0M=";
        ipv4 = [ "172.16.0.2/32" ];
        selfEndpoint = "10.0.0.3:51820";
      };
    };
  };
  
  networking.firewall.interfaces.your-network.allowedTCPPorts = [ 
    22 # Allow SSH over wireguard.
  ];
}
```

### Matching up machines to peers.

This is the most error prone part of this procedure. Flake-guard has no idea which host it's supposed to be inside of `wireguard.networks.<NETWORK>.peers.by-name`. This can be adjusted via two options

- `wireguard.hostName`
- `networking.hostName`

In the order of precedence given from top to bottom, flake-guard will use options to determine which host is equal to the in `wireguard.networks.<NETWORK>.peers.by-name.<HOSTNAME>`

```
imports = [ ./network.nix ];
networking.hostName = "host1";
# or
# wireguard.hostName = "host1";
```

#### `wireguard.build.networks.<NETWORK>.self`

is constructed whenever a machine finds its self in the network.

`wireguard.build.networks.<NETWORK>._responsible` 
will contain every instance that potentially matched `self`. 
Under normal operating conditions, this should always be the length of `1`.
Its inclusion is for debug purposes.


### Scoping default value.

Flake-guard will default values based on the parent attr-set, 
otherwise the precedence is in the order of:


- `wireguard.networks.<NETWORK>.peers.by-name.<HOST>`
- `wireguard.networks.<NETWORK>`
- `wireguard.defaults`

```nix 
 wireguard.networks.testnet = {
    secretsLookup = "default-value-for-each-peer";
    
    peers.by-name = {
      host1 = {
        publicKey = "g72lA+Jsvp7ZEmXQGpJCrzMVrorSTjr6/kbD9aaLyX0=";
        ipv4 = [ "172.16.0.1/32" ];
        selfEndpoint = "10.0.0.2:51820";
        secretsLookup = "im-different";
      };
      ...
    };
};
```

### Customizing topology.
```nix
{config, lib, pkgs, ...}:
let 
  cfg = config.networking.wireguard.networks.your-network;
in
{
  wireguard.autoConfig."networking.wireguard".interface = true;
  
  # Dont give up control on who can connect directly
  networking.wireguard.interfaces."your-network".peers = [
    cfg.peers.by-name.host2
  ];
}
```


### By-group

```nix
{config, lib, pkgs, ...}:
let 
  cfg = config.networking.wireguard.networks.your-network;
in
{
  wireguard.autoConfig."networking.wireguard".interface = true;
  wireguard.networks.testnet.peers.by-name = {
    host1 = {
      publicKey = "g72lA+Jsvp7ZEmXQGpJCrzMVrorSTjr6/kbD9aaLyX0=";
      ipv4 = [ "172.16.0.1/32" ];
      selfEndpoint = "10.0.0.2:51820";
      groups = ["bridges"];
    };
    
    host2 = {
      publicKey = "ic/rfXxqoA4U0eaiL2VvVdkPIjvQL5p0lO/kk2lWZ0M=";
      ipv4 = [ "172.16.0.2/32" ];
      selfEndpoint = "10.0.0.3:51820";
      groups = ["bridges"];
    };
  };
  
  # Using groups can reduce mental loads when re-exaiming code
  networking.wireguard.interfaces."your-network".peers =
    (builtins.attrValues cfg.peers.by-group.bridges);
}
```
</details>

