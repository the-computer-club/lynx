{ config, lib, ... }:
{
  flake.nixosModules =
    let
      transform = cfg:
        {
          home-manager = {
            users.${cfg.username} = ({lib, ...}: {
              imports = cfg.modules;
              home.homeDirectory = lib.mkDefault cfg.directory;
              home.username = lib.mkDefault cfg.username;
            });
            extraSpecialArgs = cfg.specialArgs;
            useGlobalPkgs = true;
            useUserPackages = true;
          };
        };

      home-config = transform: xattr:
        builtins.attrValues
          (lib.mergeAttrs {}
            (lib.mapAttrs (k: v: { "${k}-home" = transform v; })
              xattr));

    in
      lib.fold lib.recursiveUpdate {}
        (home-config transform config.profile-parts.home-manager);
}
