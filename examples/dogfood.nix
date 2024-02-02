{config, lib, ...}: # In the flake module
let
  flake-cfg = config;
in
{
  flake.nixosModules.my-fancy-service = {lib, config, pkgs, ... }:
    { # in the nixos Module
      options.services.my-fancy-service = {
        enable = lib.mkEnableOption "fancy service";
        package = lib.mkOption {
          default = flake-cfg.packages.my-wrapper;
        };
      };
    };

    perSystem = {config, lib, pkgs, ...}:
      {
        packages.my-script = pkgs.callPackage(
          {writeShellScript, cowsay, ...}:
          writeShellScript "something-fancy.sh"
            ''
              ${pkgs.cowsay}/bin/cowsay "flake parts!"
            ''
        ) {};

        packages.my-wrapper = pkgs.callPackage (
          { my-script, writeShellScript, ... }:
          writeShellScript "fancy-cow.sh"
            ''
            ${my-script} > ./remember-me
            ''
        ) { my-script = config.packages.my-script; };
      };
}
