{
  description = "Repository of shared modules";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.flake-parts.inputs.nixpkgs.follows = "nixpkgs";

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; }
    ({
      systems = ["x86_64-linux"];

      flake.flakeModules = {
        builtins = ./flake-modules/builtins;
        deploy-rs = ./flake-modules/deploy-rs;
        lynx-docs = ./flake-modules/lynx-docs;
        flake-guard = ./flake-modules/flake-guard/flake-module.nix;
        domains = ./flake-modules/domains;
        profile-parts-homexts = ./flake-modules/profile-parts-homext.nix;
        unit-test = ./flake-modules/unit-test;
      };

      flake.nixosModules = {
        wg-name = ./nixos-modules/wg-name;
        flake-guard-host = ./flake-modules/flake-guard/nixos-module.nix;
        globals = ./nixos-modules/globals.nix;
        fs.zfs = {
          encrypted-ephemeral = ./nixos-modules/fs/zfs/encrypted-ephemeral.nix;
          reuse-password-prompt = ./nixos-modules/fs/zfs/reuse-password-prompt.nix;
        };
      };

      perSystem = {config, lib, pkgs, ...}:
      {
        packages.wireguard-tools = pkgs.callPackage ./pkgs/wg-name/wireguard-tools.nix {
          wg-name = pkgs.python3Packages.callPackage ./pkgs/wg-name/wg-name.nix {};
        };
      };

      flake.lib = ./lib.nix;
      flake.recipesPath = ./recipes;
    });
}
