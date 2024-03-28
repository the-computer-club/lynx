{config, lib, ...}:
let
  cfg = config.my-flake-module;
in
{
  options.my-flake-module = {
    enable = lib.mkEnableOption "enable my-flake-module";
  };

  config = lib.mkIf cfg.enable
  {
    #places on the top level of the flake
    flake.hello = "hello";

    #accessing pkgs, and defining your own
    perSystem = {config, lib, pkgs, ...}: {
      packages.foobar = pkgs.hello;
    };
  };
}
