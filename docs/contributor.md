# Contribution Quick start

Lynx does not contain any inputs.

Configurations flake/nixos modules are loaded by the end user, and their system configurations the variable `pkgs`

Flake parts is the primary back bone of this project, allowing for the top level of flakes to be composed with the nixos-module mechanism.


Do not use overlays, as many flakes can do without them.

### Writing Flake Modules

``` nix
# your flake.nix
{
  description = "flake example";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    parts.url = "github:hercules-ci/flake-parts";
    lynx.url = "github:the-computer-club/lynx";
  };

  outputs = inputs@{self, parts, nixpkgs, ...}:
    parts.lib.mkFlake { inherit inputs; }
    (_: # https://flake.parts/module-arguments
    {
      systems = ["x86_64-linux"];
      imports = [ lynx.flakeModules.my-flake-module ];
      
      lynx.my-flake-module.enable = true;
      flake.world = "world";
    });
}
```

```sh
nix repl
> :lf .
...
> self.outputs.hello
> "hello"
> self.outputs.world
> "world"
> self.outputs.packages.x86_64-linux
> <derivation hello>
```

## Defining a Nixos Module 
```nix
{config, lib, pkgs, ...}: 
{
    options.lynx.yak.enable = mkEnableOption "enable yak";
    config = mkIf config.lynx.yak.enable {
       environment.etc."yak.cowboy".text = "yehaw";
    };
}
```

``` nix
# flake.nix (lynx dev)
{
    flake.nixosModules.yak = import ./nixos-modules/yak.nix;
}
```


## Putting it all together
``` nix
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

```




