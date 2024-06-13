{
  inputs
  , config
  , lib
  , flake-parts-lib
  , ...
}:
{
  options.domains = lib.mkOption {
    default = {};

    description = ''
      evaluate flake modules as their under their own namespace,
      seperate from the parent. These options are built on their
      respective names in `config.build.domains`
    '';

    example = ''
      domains."hello-world".specialArgs = {  };
      domains."hello-world".modules = [
        ({inputs, config, lib, ...}: {
          systems = ["x86_64-linux"];
          imports = [ inputs.lynx.flakeModules.flake-guard ];

          wireguard.enable = true;
          wireguard.networks.vxlan = {
            sopsLookup = "wg-vxlan";
            peers.by-name.gateway = {
              publicKey = "nwDPjwn9KPKw2wYNMe0CHP5oIJBJHFruRy62EoTjU1A=";
              ipv4 = ["172.16.1.1"];
            };
          };
        })
      ];
    '';

    type = with lib.types; attrsOf (submodule {
      options.modules = lib.mkOption {
        type = listOf deferredModule;
        default = [];
      };

      options.specialArgs = mkOption {
        type = attrsOf raw;
        default = {};
      };
    });
  };

  options.build.domains = lib.mkOption {
    type = with lib.types; lazyAttrsOf raw;
    default = {};
  };

  config.build.domains = builtins.mapAttrs(domain: toplevel:
    (flake-parts-lib.evalFlakeModule {
      inherit inputs;
    } toplevel)
  ) config.domains;
}
