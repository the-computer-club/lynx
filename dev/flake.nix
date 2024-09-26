{
  description = "flake example";

  inputs = {
    lynx.url = "../";
    parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    home-manager.url = "github:nix-community/home-manager";
    profile-parts.url = "github:adamcstephens/profile-parts";
    disko.url = "github:nix-community/disko";
    sops.url = "github:Mic92/sops-nix";

    # deploy-rs.url = "github:adamcstephens/profile-parts";
  };

  outputs = inputs@{self, parts, lynx, nixpkgs, ...}:
    parts.lib.mkFlake { inherit inputs; }
    ({ config, withSystem, flake-parts-lib, ... }:
    let
      examples = {
        dogfood = ../examples/dogfood.nix;
        nixos-module = ../examples/nixos-module.nix;
        flake-module =  ../examples/flake-module.nix;
      };

      tests = {
        flake-guard = ./flake-guard;
      };

    in
    {
      systems = ["x86_64-linux"];
      imports =
        [ lynx.flakeModules.builtins ]
        ++
        (with tests; [
          flake-guard
        ])
        ++
        (with examples; [
          dogfood
          nixos-module
          flake-module
        ])
        ++
        (with lynx.flakeModules; [
          deploy-rs
          lynx-docs
          unit-test
        ]);

      lynx.docgen.repository.baseUri = "github.com/";

      lynx.docgen.flakeModules = [
        lynx.flakeModules.deploy-rs
        lynx.flakeModules.lynx-docs
        lynx.flakeModules.flake-guard
      ];

      lynx.docgen.nixosModules = [
        lynx.nixosModules.globals
      ];


      flake._config = config;

    });
}
