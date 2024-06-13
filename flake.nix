{
  description = "Repository of shared modules";
  outputs = _: {
    lib.requireInput = x: url: inputs: cfg:
      if (inputs ? x) then cfg
      else assert ''
        requires "${x}" as input.

        place the following snippet in your flake.nix file
        to use this functionality:

        inputs.${x}.url = ${url}
      '';

    flakeModules = {
      deploy-rs   = import ./flake-modules/deploy-rs;
      lynx-docs   = import ./flake-modules/lynx-docs;
      flake-guard = import ./flake-modules/flake-guard;
      profile-parts-homexts = import ./flake-modules/profile-parts-homext.nix;
    };

    nixosModules = {
      globals = import ./nixos-modules/globals.nix;
      fs.zfs = {
        encrypted-ephemeral = import ./nixos-modules/fs/zfs/encrypted-ephemeral.nix;
        reuse-password-prompt = import ./nixos-modules/fs/zfs/reuse-password-prompt.nix;
      };
    };
  };
}
