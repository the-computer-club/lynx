{
  description = "flake example";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    parts.url = "github:hercules-ci/flake-parts";

    home-manager.url = "github:nix-community/home-manager/release-23.11";
    profile-parts.url = "github:adamcstephens/profile-parts";

    lynx.url = "github:the-computer-club/lynx";
    disko.url = "github:nix-community/disko";
  };

  outputs = inputs@{self, parts, nixpkgs, home-manager, ...}:
    parts.lib.mkFlake { inherit inputs; }
    ({ withSystem, flake-parts-lib, ... }:
    let
      inherit (flake-parts-lib) importApply;
      flakeModules = {
        top-level = importApply ./parts/top-level.nix { inherit withSystem; };
      };
    in
    {
      imports = [
        flakeModules.top-level
      ];

      systems = ["x86_64-linux"];

      flake = { inherit flakeModules; };
    });
}
