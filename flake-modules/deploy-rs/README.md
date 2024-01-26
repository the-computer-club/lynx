# deploy-rs 

adds deploy-rs as flake module

``` nix
parts.mkFlake {
  deploy = {
    nodes.<nixosConfiguration>.hostname = "1.1.1.1";
    defaultUser = "root";
    defaultSshUser = "lunarix";
    defaultSystem = "x86_64-linux"
    defaultSshOpts = ["-t"];
  };
    
  flake = { ... }
}
```


