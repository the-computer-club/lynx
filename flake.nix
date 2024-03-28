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
      fs.zfs = {
        encrypted-ephemeral = ./nixos-modules/fs/zfs/encrypted-ephemeral.nix;
        reuse-password-prompt = ./nixos-modules/fs/zfs/reuse-password-prompt.nix;
      };
    };
  };
}
