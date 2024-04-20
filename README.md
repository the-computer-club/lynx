# lynx
lynx is an opinionated (edumucated) utility box for nixos configurations. 
lynx primarily uses the flake-parts framework.

lynx aims to have similar goals to nixpkgs, providing documentation, testing, and source code.

> [!WARNING]
> This product assumes you're already familiar with the nix ecosystem. Error messages produced by the module system can be unclear and sometimes not informative. Documentation, and other resources in this repository may expect such literacy from its users. 


## Bibliography
- https://github.com/tweag/rfcs/blob/flakes/rfcs/0049-flakes.md
- https://flake.parts
- https://unallocatedspace.dev/blog/emc2i-flake

``` nix
{
  description = "minimal flake example";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    parts.url = "github:hercules-ci/flake-parts";
    lynx.url = "github:the-computer-club/lynx";
  };

  outputs = inputs@{self, parts, nixpkgs, lynx, ...}:
    parts.lib.mkFlake { inherit inputs; }
    (_: # https://flake.parts/module-arguments
    {
      systems = ["x86_64-linux"];
      imports = [ ];
      
      flake.nixosConfigurations.default = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs self; }
          modules = [
              ./configuration.nix
              ./hardware-configuration.nix
          ];
      };
    });
}
```
