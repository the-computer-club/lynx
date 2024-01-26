# deploy-rs 

adds deploy-rs as flake module

``` nix

imports = [ lynx.flakeModules.deploy-rs ];

deploy = {
  input = inputs.deploy;
  defaultSshUser = "lunarix";
  defaultSshOpts = [ "-t" ];
  nodes = {
    cypress.hostname = "10.0.0.5";
    cardinal.hostname = "unallocatedspace.dev";
    charmander.hostname = "10.0.0.62";
  };
};
```


