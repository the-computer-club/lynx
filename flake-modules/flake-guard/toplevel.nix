args@{ config, lib, ... }:
with lib;
let
  network-options = import ./network-options.nix args;
  autoconfig-options = import ./autoconfig-options.nix args;

  mkDefaultStr = description: mkOption {
    inherit description;
    type = types.nullOr types.str;
    default = null;
  };

  inherit (import ./lib.nix args)
    composeNetwork;
in
{
  options = {
    defaults = {
      autoConfig = mkOption {
        type = (types.submodule autoconfig-options);
        default = {};
      };

      nameAsFQDN = mkEnableOption "use hostname as fqdn";
      secretsLookup = mkDefaultStr ''used by `config.[age|sops].secrets ? "''${secretsLookup}"`'';
      privateKeyFile = mkDefaultStr "file path to the private key used for this host";

      domainName = mkDefaultStr "asdasd";

      authority = {
        rootCertificate = mkOption {
          type = types.nullOr types.path;
          description = ''
            ACME root certificate.
          '';
          default = null;
        };

        subca = mkOption {
          type = types.attrsOf (types.submodule ./subca-options.nix);
          default = {};
        };
      };
    };

    networks = mkOption {
      default = {};
      description = ''describes a wireguard network. '';
      type = types.attrsOf (types.submodule network-options);
    };

    build.networks = mkOption {
      description = ''
        this is composed from the options defined in wireguard.networks; including assigned defaults.
        this option exists for the flake-parts scope which expect a composed network at the flake level.
        Other wise in the nixos context, one is provided in the nixos-module.nix
        under `wireguard.build._stubbed`
      '';
      type = types.attrsOf (types.submodule network-options);
      default = {};
    };

    lib = mkOption {
      description = "references to the library";
      type = types.unspecified;
      default = import ./lib.nix args;
    };
  };
}
