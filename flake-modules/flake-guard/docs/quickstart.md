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

Note: If you're using flake-parts. All the options from `wireguard.*` can be defined within your flake's scope.

At this point in time, not much tooling takes advantage of this aspect. In the future, we imagine a situation where
someones wants to make wireguard effect `packages`.

```nix
{
  inputs.lynx.url = "github:the-computer-club/lynx";
  
  outputs = inputs@{self, parts, lynx, nixpkgs, peers, ...}:
    parts.lib.mkFlake { inherit inputs; }
    ({ config, ... }: {
 
      imports = [ 
        lynx.flakeModules.flake-guard
      ];
      
      wireguard.enable = true;
      
      wireguard.networks.your-network = {
        peers.by-name.your-host = {
          ...
        };
      }

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
> It is a common strategy to generate a wireguard key for each host, and then reference them all the same under the same namespace.
> Under each nixos-module's context, the underlying value evaluates to a different secret.
> The examples below also follow this strategy.
> If not specified, flake-guard assumes the network name as the `secretsLookup` as a last-shot effort.


### Secrets Backends supported are

- [agenix](https://github.com/ryantm/agenix)
- [sops-nix](https://github.com/Mic92/sops-nix)
- `privateKeyFile`
- `privateKey` (For testing purposes only)
---


## Generate wireguard keypair

```sh
nix shell nixpkgs#wireguard-tools

wg genkey | tee /tmp/wg-private-key | wg pubkey
```


### SecretsLookup

- `wireguard.networks.<NETWORK>.secretsLookup`

secrets are derived from the following expression
```
config.<age|sops>.secrets."${config.wireguard.networks.<NETWORK>.secretsLookup}"
```

included in: `lynx.nixosModules.flake-guard-host`.


### PrivateKeyFile
generate a key pair, then copy the public key.

```sh
wg genkey | tee /var/lib/wireguard/privatekey | wg pubkey
```

```nix
wireguard.networks.your-network = {
  privateKeyFile = "/var/lib/wireguard/privateKeyFile";
  
  peers.by-name."your-host" = {
    publicKey = "the output from wg pubkey";
    ipv4 = ["172.0.1.1/32"];
    selfEndpoint = "10.0.0.5:" 
  };
};

```

---
### Sops

Add the secrets information to `.sops.yaml`
```yaml
# .sops.yaml
path: host/secrets.json
- keys:
  - &user
```

Create the encrypted file.
```sh
EDITOR=code sops host/secrets.json
```

Paste in your private key
```json
# secrets.json
{ "your-network": "AFN6afBcZyzKnjkdBztgEpVH3mmlcNUEo5vtDQuqy0s=" }
```


```nix
sops.secrets."your-network".file = ./hosts/secrets.json;

wireguard.networks.your-network = {
  secretsLookup = "your-network";
  peers.by-name."your-host" = {
    publicKey = "the output from wg pubkey";
    ipv4 = ["172.0.1.1/32"];
  };
};
```

---
### Age

add the encrypted file by running and pasting in the private key.

```sh
EDITOR=emacs agenix -e host1-your-network.age
```


add the following configuration to your hosts. 
Where each host appropriately knows its own secrets.
```nix
# secrets.nix
age.secrets."your-network".file = ./host1-your-network.age;
```

```nix
wireguard.networks.your-network = {
  secretsLookup = "your-network";
  peers.by-name."your-host" = {
    publicKey = "the output from wg pubkey";
    ipv4 = ["172.0.1.2/32"];
  };
};
```

---

### Configuring `configuration.nix`

instead the nixos `configuration.nix` the name (`peers.by-name.<NAME>`) field has to match either

- `networking.hostName`
- `wireguard.hostName`

```nix
wireguard.hostname = "your-host";
```

### Configure outputs

Each host has to know how to build wireguard configurations.

In this example, we'll be targeting `networking.wireguard` and `networking.hosts`

Currently we only support the two  `autoConfig` mentioned, 
but you can implement your own with `config.wireguard.build.networks`

```nix
wireguard.networks.your-network.autoConfig = {
  # Punch a port through the firewall
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
```

</details>

<details>
<summary><b>3. Finalizing the network. </b></summary>


## Adding more peers
Adding more peers is as simple as adding their public keys, and their respective `selfEndpoints`
`selfEndpoints` are where peers, other than the host themselves will connect to.


```nix
# network.nix
  
wireguard.networks.your-network = {
  listenPort = 51820;
  secretsLookup = "your-network"; 

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
```


#### `wireguard.build.compose.<NETWORK>`
This option contains the input from `wireguard.networks.<NETWORK>`, 
but has applied `defaults` + `network` configurations. This variant does not carry `self`


#### `wireguard.build.networks.<NETWORK>.self`

is constructed whenever a machine finds its self in the network.

The field contains the information from `peers.by-name.<HOST>`, 
with the inclusion of some helper fields under `peers.by-name.<HOST>.build`

`wireguard.build.networks.<NETWORK>._responsible` 
will contain every instance that potentially matched `self`. 
Under normal operating conditions, this should always be the length of `1`.
Its inclusion is for debug purposes. 


If `self` cannot be found, consider checking the possible locations.

- `wireguard.hostname`
- `networking.hostname`
- `peers.by-name.<NAME>`
- `nix eval .#nixosConfigurations.<HOST>.config.wireguard.build.networks.<NETWORK>._responsible`

Some more advanced configurations can be done when self is used.
```nix
let 
  netcfg = config.wireguard.build.networks.your-network;
in
services.nginx.listenAddresses = [ netcfg.self.build.ipv4.first ];
```


### High assurance tunnels (TODO)
High assurance tunnels are best used in deployment environments where the changes 
applied aren't used until the next reboot. This feature is included for the use of `colemna` and `deploy-rs` 
where changes to `flake-guard` or underlying `autoConfig` targets are updated, 
they sometimes cause tunnels to be unaccessible.

```nix
wireguard.networks.your-network.restartIfChanged = false;
wireguard.networks.your-network.peers.by-name.your-host.restartIfChanged = false;
```


### Defaults.

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
  netcfg = config.networking.wireguard.networks.your-network;
in
{
  wireguard.autoConfig."networking.wireguard".interface = true;
  
  # Dont give up control on who can connect directly
  networking.wireguard.interfaces."your-network".peers = [
    netcfg.peers.by-name.host2
  ];
}
```


### By-group

```nix
{config, lib, pkgs, ...}:
let 
  netcfg = config.networking.wireguard.networks.your-network;
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
    (builtins.attrValues netcfg.peers.by-group.bridges);
}
```
</details>

