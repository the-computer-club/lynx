{
  description = "Repository of shared modules";
  outputs = _: {
    flakeModules = {
      deploy-rs   = import ./flake-modules/deploy-rs;
      lynx-docs   = import ./flake-modules/lynx-docs;
      flake-guard = import ./flake-modules/flake-guard;
      profile-parts-homexts = import ./flake-modules/profile-parts-homext.nix;
    };

    nixosModules = {
      globals = import ./nixos-modules/globals.nix;
    };
  };
}
