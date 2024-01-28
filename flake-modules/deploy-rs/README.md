# deploy-rs 

adds deploy-rs as flake module, this module only adds types for the `deployment` toplevel flake attribute.

``` nix
imports = [ lynx.flakeModules.deploy-rs ];

deploy = {
  sshUser = "lunarix";
  user = "root";
  magicRollback = false;
  nodes = {
    cypress = {
      hostname = "10.0.0.5";
      profiles.system = {
        path = inputs.deploy.lib."x86_64-linux".activate.nixos
          self.nixosConfigurations.cypress;
      };
    };
  };
};
```


