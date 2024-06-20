{
  description = "Repository of shared modules";
  outputs = _: {
    flakeModules = {
      "builtins" = ./flake-modules/builtins;
      deploy-rs = ./flake-modules/deploy-rs;
      lynx-docs = ./flake-modules/lynx-docs;
      flake-guard = ./flake-modules/flake-guard;
      domains = ./flake-modules/domains;
      profile-parts-homexts = ./flake-modules/profile-parts-homext.nix;
    };

    nixosModules = {
      globals = ./nixos-modules/globals.nix;
      fs.zfs = {
        encrypted-ephemeral = ./nixos-modules/fs/zfs/encrypted-ephemeral.nix;
        reuse-password-prompt = ./nixos-modules/fs/zfs/reuse-password-prompt.nix;
      };
    };

    lib = ./lib.nix;
  };
}
