{
  description = "flake example";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    parts.url = "github:hercules-ci/flake-parts";
    lynx.url = "path:../";
  };

  outputs = inputs@{self, parts, lynx, nixpkgs, ...}:
    parts.lib.mkFlake { inherit inputs; }
    ({ withSystem, flake-parts-lib, ... }:
    {
      systems = ["x86_64-linux"];
      imports = [
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
              alias build="nix flake update && nix build .#generateDocsHTML"
            '';
          };
        };
    });
}
