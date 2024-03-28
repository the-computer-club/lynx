{config, lib, ...}:
let cfg = config.lynx-test.yak;
in
{
  options.lynx-test.yak.enable = lib.mkEnableOption "enable yak";
  config = lib.mkIf cfg.enable
    {
      flake.nixosModules.lynx.yak = {...}: {
        environment.etc."yak.cowboy".text = "yehaw";
      };
    };
}
