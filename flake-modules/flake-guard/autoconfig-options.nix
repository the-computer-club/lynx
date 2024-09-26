{ config, lib, ... }:
with lib;
{
  options = {
    openFirewall = mkEnableOption "automatically open the firewall";

    "networking.wireguard" = {
      interface.enable = mkEnableOption "setup ips & privateKey";
      peers.mesh.enable = mkEnableOption "write all peers from the `<network>.peers.by-name` into the interface";
    };

    "networking.hosts" = {
      enable = mkEnableOption "";
      FQDNs.enable = mkEnableOption "write FQDNs into /etc/hosts";
      bareNames.enable = mkEnableOption "write hostName into /etc/hosts";
      names.enable = mkEnableOption
      ''
        write extraHostNames into /etc/hosts.
      '';
    };
  };
}
