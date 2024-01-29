{
  description = "Repository of shared modules";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{self, parts, ...}:
    parts.lib.mkFlake { inherit inputs; }
    ({ withSystem, flake-parts-lib, ... }:
    let
      inherit (flake-parts-lib) importApply;
      flakeModules = {
        deploy-rs = importApply ./flake-modules/deploy-rs { inherit withSystem; };
        lynx-docs = importApply ./flake-modules/lynx-docs { inherit withSystem; };
      };
    in
    {
      systems = ["x86_64-linux"];
      imports = [flakeModules.lynx-docs];

      flake = {
        inherit flakeModules;
        repository = {
          flake = "github:the-computer-club/lynx/";
          uri = "https://github.com/the-computer-club/lynx/tree/main/";
        };
        nixosModules = {
          globals = import ./nixos-modules/globals.nix;
        };
      };
    });
}
