{ config, lib, pkgs, ... }:
with lib;
# Global settings
#
# flake-guard = {
#   defaults = {
#     sops.enable = true;
#     age.enable = true;
#     autoConfig = {
#       "networking.wireguard.interfaces" = {
#         ips.enable = mkDefault true
#         privateKey.enable = mkDefault true;
#         peers.enable = true;
#       };
#
#       "networking.hosts" = {
#         Fqdns.enable = true;
#       };
#     };
#   };
#
#   peers.by-name = { ... };
#   
#
# };
#
#
{
  options = {
    sops = {
      enable = mkEnableOption ''
        enable looking up secrets via `sops.secrets ? <lookup>`.
        enabling this without age will not cause errors, and instead skip the check
      '';

      key = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };

    age.enable = mkEnableOption ''
        enable looking up secrets via `age.secrets ? <lookup>`.
        enabling this without age will not cause errors, and instead skip the check
      '';

    autoConfig = {
      "networking.wireguard.interfaces" = {
        ips.enable = mkEnableOption "write to networking.wireguard.interfaces";
        privateKey.enable = mkEnableOption "write to networking.wireguard.interfaces";
        peers.enable = mkEnableOption "write in peer list";
      };

      "networking.hosts" = {
        hostnames.enable = mkEnableOption "write unqualified hostnames without any suffix";
        Fqdns.enable = mkEnableOption "write fully qualified hostnames with suffixes";
      };

      "security.acme.certs" = {
        enable = mkEnableOption "write to security.acme.certs";

        keyName = mkOption {
          description = "key name for acme cert, default is network.self.fqdn";
          type = types.nullOr types.str;
          default = null;
        };

        server = mkOption {
          type = types.nullOr types.nonEmptyStr;
          default = null;
        };
      };

      "security.pki.trustedCertificateFile" = {
        enable = mkEnableOption "added trusted certs";
        acmeTrustedCertificateFiles = lib.mkOption {
          type = with types; (listOf (either str path));
          default = [];
        };
      };
    };
  };
}
