# lynx
lynx is an opinionated (edumucated) utility box for nixos configurations. 
lynx primarily uses the flake-parts framework.

lynx aims to have similar goals to nixpkgs, providing documentation, testing, and source code.

## Bibliography
- https://flake.parts

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
