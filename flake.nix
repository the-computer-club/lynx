{
  description = "Repository of shared modules";
  inputs.parts.url = "github:hercules-ci/flake-parts";
  outputs = inputs@{self, parts, ...}:
    parts.lib.mkFlake { inherit inputs; }
    ({ withSystem, flake-parts-lib, ... }:
    let
      inherit (flake-parts-lib) importApply;
      flakeModules = {
        deploy-rs = importApply ./flake-modules/deploy-rs { inherit withSystem; };
      };
    in
    {
      flake = {
        inherit flakeModules;

        nixosModules = {
          globals = import ./nixos-modules/globals.nix;
        };
      };
    });
}
