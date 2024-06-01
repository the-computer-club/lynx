{
  description = "flake example";

  inputs = {
    lynx.url = "path:../";
    parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    profile-parts.url = "github:adamcstephens/profile-parts";

    disko.url = "github:nix-community/disko";
    # deploy-rs.url = "github:adamcstephens/profile-parts";
  };

  outputs = inputs@{self, parts, lynx, nixpkgs, ...}:
    parts.lib.mkFlake { inherit inputs; }
    ({ withSystem, flake-parts-lib, ... }:
    {
      systems = ["x86_64-linux"];
      imports = [
        ../examples/dogfood.nix
        ../examples/nixos-module.nix
        ../examples/flake-module.nix
        lynx.flakeModules.deploy-rs
        lynx.flakeModules.lynx-docs
      ];

      lynx.docgen.repository.baseUri = "github.com/";

      lynx.docgen.flakeModules = [
        lynx.flakeModules.deploy-rs
        lynx.flakeModules.lynx-docs
      ];

      lynx.docgen.nixosModules = [
        lynx.nixosModules.globals
      ];

      perSystem = args@{ config, self', inputs', pkgs, lib, system, ... }:
        {
          packages.default = pkgs.mkShell {
            shellHook = ''
              alias build="nix flake update && nix build"
              alias repl="nix flake update && nix repl"
           '';
          };
        };
    });
}
