# flake-guard

>![WARNING]
> Unstable.

flake guard allows you to define your wireguard network once, and use it across multiple `nixosConfiguration` fields.


guides:
- [sops](./sops.md)
- [age](./age.md)
- [local-key](./local-key.md)



flake guard uses flake-parts to define options in at the level. `wireguard.networks.<name>.peers.by-name.<hostname>`.

These options are effectively the same as `wireguard.networking.interfaces.peers.*`.


flake guard then provides an nixosModule for interfacing with the flake-level data. This interface is generated on your flake as `self.nixosModule.flake-guard-host`.

The peer list is the primary data structure needed to configure the wireguard network, so if you wish to implement your own variation, this is the core premise.

`flake-guard-host` provides `networking.wireguard.networks.<name>`
which introduces the following

|------------|--------------------------------------------------------------------|
| peers      | the network's peer list, same as the flake level.                  |
| self       | this host selected from the peer list                              |
| autoConfig | will use the data above automatically for the respective interface |
|            |                                                                    |

`flake-guard-host` makes an attempt to "discover" which system its ran on. This is accomplished by checking `networking.hostName`, and matching the name from `peers.by-name`. 

`networking.wireguard.networks.autoConfig` will not work without it.


