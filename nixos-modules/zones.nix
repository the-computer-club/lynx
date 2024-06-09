{ inputs, config, lib, ... }:
inputs.lynx.lib.requireInput
  "dns" "github:kirelagin/dns.nix" inputs

(with inputs;
{
  imports = [ inputs.dns.nixosModules.dns ];

  options.networking.zones = lib.mkOption {
    type = lib.types.attrsOf dns.lib.types.zone;
    description = "DNS zones";
  };

  options.build.networking.zones = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = {};
  };

  config.networking.build.zones = mapAttrs(k: v: {
    "${k}".data = inputs.dns.lib.toString k v;
  }) config.networking.zones;

  config.services.nsd.zones = mkIf config.services.nsd.enable
    config.build.networking.zones;
})
