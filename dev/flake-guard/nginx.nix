{ config, lib, pkgs, ... }:
{
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "nginx@example.org";
      server = "https://acme:8443/acme/acme/directory";
    };
  };

  services.nginx = {
    enable = true;

    virtualHosts."nginx.vpn" = {
      forceSSL = true;
      enableACME = true;
    };

    virtualHosts."nginx" = {
      forceSSL = true;
      enableACME = true;
    };
  };
}
