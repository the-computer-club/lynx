{
  description = "Repository of shared modules";
  outputs = _: {
    flakeModules = {
      deploy-rs = import ./flake-modules/deploy-rs;
      lynx-docs = import ./flake-modules/lynx-docs;
    };

    nixosModules = {
      globals = import ./nixos-modules/globals.nix;
    };
  };
}
