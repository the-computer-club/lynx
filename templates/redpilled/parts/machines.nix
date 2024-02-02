{ self, inputs, config, lib, pkgs, ... }:

{
  imports = [
    inputs.profile-parts.flakeModules.nixos
    inputs.lynx.flakeModules.profile-parts-homexts
  ];

  # default settings for nixosConfigurations
  profile-parts.default.nixos = {
    nixpkgs = inputs.nixpkgs;

    # all nixosConfigurations
    # enabled by default
    enable = true;
    system = "x86_64-linux";
    exposePackages = true; # expose packages for nixosConfigurations, e.g. .#nixos/example
  };

  # global settings for nixosConfigurations
  profile-parts.global.nixos = {
    # alternative: modules = {name, profile}: [];
    modules = [
      { services.openssh.enable = true; }
    ];

    specialArgs = { inherit self inputs; };
  };

  profile-parts.nixos.default.modules = [
    ../modules/configuration.nix
    ../modules/hardware-configuration.nix
    self.nixosModules.lunarix-home
    inputs.home-manager.nixosModules.home-manager
  ];
}
