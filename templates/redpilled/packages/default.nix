{ inputs, config, lib, pkgs, ... }:
let
  flakecfg = config;
in
{
  flake.nixosModules.flake-packages = {config, lib, pkgs, ...}: {
    imports = [ inputs.lynx.nixosModules.globals ];
    globals.packages = flakecfg.packages;
  };

  perSystem = { pkgs, config, lib, ...}:
  {
    packages.web-scraper = pkgs.callPackage( {curl, writeShellScript }:
      writeShellScript "scrape.sh" ''
        ${pkgs.curl}/bin/curl -s https://example.com > /tmp/scraped.html
        ''
    );
  };
}
