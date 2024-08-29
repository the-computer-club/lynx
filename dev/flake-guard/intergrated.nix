{ config, lib, pkgs, ... }:
let net = config.wireguard.networks.testnet;
in {
  security.acme = {
    acceptTerms = true;
    defaults.email = "integrated@example.org";
    defaults.server = net.metadata.acmeServer;
  };

  services.nginx = {
    enable = true;
    virtualHosts.${net.self.fqdn} = {
      forceSSL = true;
      enableACME = true;
    };
  };
}
