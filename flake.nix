{
  description = "Repository of shared modules";
  outputs = _: {
    flakeModules = {
      deploy-rs   = import ./flake-modules/deploy-rs;
      lynx-docs   = import ./flake-modules/lynx-docs;
      flake-guard = import ./flake-modules/flake-guard;
      domains = import ./flake-modules/domains;
      profile-parts-homexts = import ./flake-modules/profile-parts-homext.nix;
    };

    nixosModules = {
      globals = import ./nixos-modules/globals.nix;
      fs.zfs = {
        encrypted-ephemeral = import ./nixos-modules/fs/zfs/encrypted-ephemeral.nix;
        reuse-password-prompt = import ./nixos-modules/fs/zfs/reuse-password-prompt.nix;
      };
    };

    lib = import ./lib.nix;
  };
}
