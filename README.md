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
    let
      lynx' = import lynx.lib { flake-parts-lib=parts.lib; };
      # mkFlake with config.assertions and 
      # config.warnings support
      ## parts.lib.mkFlake can be used instead aswell.
      mkFlake = lynx'.mkFlakeWithAssertions;
    in
    mkFlake { inherit inputs; }
    (_: # https://flake.parts/module-arguments
    {
      systems = ["x86_64-linux"];
      imports = with lynx.flakeModules; [
        wireguard  # define a wireguard network once, and use it everywhere.
        deploy-rs    # types for deploy-rs
        domains      # evaluate flake modules in their own namespace
        # "builtins" # include this if you're using `parts.lib.mkFlake` 
                     # instead `of `mkFlakeWithAssertions` 
      ];

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
