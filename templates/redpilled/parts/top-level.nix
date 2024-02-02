{ self, inputs, config, lib, pkgs, ... }:
{
  imports = [
    ./home-manager.nix
    ./machines.nix
    ../packages
  ];
}
