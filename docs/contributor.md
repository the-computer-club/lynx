# Contribution Quick start

Lynx does not contain any inputs.

Configurations flake/nixos modules are loaded by the end user, and their system configurations the variable `pkgs`

Flake parts is the primary back bone of this project, allowing for the top level of flakes to be composed with the nixos-module mechanism.


### Writing Flake Modules
``` nix
# flake-module.nix
{config, lib, ...}:
{
  options.lynx.my-flake-module = {
    enable = lib.mkEnableOption "enable my-flake-module";
  };
  
  config = lib.mkIf {
    # places on the top level of the flake
    flake.hello = "hello";
  
    # accessing pkgs, and defining your own
    perSystem = {config, lib, pkgs, ...}: {
      packages.foobar = pkgs.hello;
    };
  };
}
```

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


## Using self defined packages

``` nix
{
    perSystem = {config, lib, pkgs, ...}:
    {
        packages.my-script = pkgs.callPackage(
            {writeShellScriptBin, cowsay, ...}:
                writeShellScriptBin "something-fancy.sh" { buildInputs=[ cowsay ]; } 
                ''
                cowsay "flake parts!"
                '';
        ) {};
        
        packages.my-wrapper = pkgs.callPackage(
            { my-script, writeShellScriptBin, ... }: 
                writeShellScriptBin "fancy-cow.sh" { buildInputs = [ my-script ]; } 
                ''
                something-fancy.sh > ~/remember-me
                ''
        ) { my-script = config.my-script; };
    }

}
```




