{ config, lib, pkgs, ... }:

{
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  services.caddy =
    let conf =
      ''
        respond "Welcome to Caddy!"
        tls caddy@example.org {
          ca https://acme:8443/acme/acme/directory
        }
      '';
    in
  {
    enable = true;
    virtualHosts."caddy.vpn".extraConfig = conf;
    virtualHosts."caddy".extraConfig = conf;
  };
}
